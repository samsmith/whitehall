require "test_helper"
require 'support/consultation_csv_sample_helpers'

class ImportTest < ActiveSupport::TestCase
  include ConsultationCsvSampleHelpers

  setup do
    @automatic_data_importer = create(:importer, name: "Automatic Data Importer")
  end

  test "valid if known type" do
    i = Import.new(csv_data: consultation_csv_sample, data_type: "consultation")
    assert i.valid?, i.errors.full_messages.to_s
  end

  test "invalid if unknown type" do
    refute Import.new(csv_data: consultation_csv_sample, data_type: "not_valid").valid?
  end

  test 'invalid if row is invalid for the given data' do
    Whitehall::Uploader::ConsultationRow.stubs(:heading_validation_errors).with(['a']).returns(["Bad stuff"])
    i = Import.new(csv_data: "a\n1", creator: stub_record(:user), data_type: "consultation")
    refute i.valid?
    assert_includes i.errors[:csv_data], "Bad stuff"
  end

  test 'invalid if any row lacks an old_url' do
    i = Import.new(csv_data: consultation_csv_sample("old_url" => ""), creator: stub_record(:user), data_type: "consultation")
    refute i.valid?, i.errors.full_messages.join(", ")
    assert_equal ["Row 2: old_url is blank"], i.errors[:csv_data]
  end

  test 'invalid if any an old_url is duplicated within the file' do
    i = Import.new(csv_data: consultation_csv_sample({"old_url" => "http://example.com"}, [{"old_url" => "http://example.com"}]), creator: stub_record(:user), data_type: "consultation")
    refute i.valid?, i.errors.full_messages.join(", ")
    assert_equal ["Duplicate old_url 'http://example.com' in rows 2, 3"], i.errors[:csv_data]
  end

  test 'valid if a whole row is completely blank' do
    blank_row = Hash[minimally_valid_consultation_row.map {|k,v| [k,'']}]
    i = Import.new(csv_data: consultation_csv_sample(blank_row), creator: stub_record(:user), data_type: "consultation")
    assert i.valid?, i.errors.full_messages.join(", ")
  end

  test "invalid if file has invalid UTF8 encoding" do
    csv_data = File.open(Rails.root.join("test/fixtures/invalid_encoding.csv"), "r:binary").read
    csv_file = stub("file", read: csv_data, original_filename: "invalid_encoding.csv")
    i = Import.create_from_file(stub_record(:user), csv_file, "consultation")
    refute i.valid?
    assert i.errors[:csv_data].any? {|e| e =~ /Invalid UTF-8 character encoding/}
  end

  test "accepts UTF8 byte order mark" do
    csv_data = File.open(Rails.root.join("test/fixtures/byte_order_mark_test_sample.csv"), "r:binary").read
    csv_file = stub("file", read: csv_data, original_filename: "byte_order_mark_test_sample.csv")
    i = Import.create_from_file(stub_record(:user), csv_file, "consultation")
    assert_equal 'old', i.csv_data[0..2]
  end

  test "doesn't raise if some headings are blank" do
    i = Import.new(csv_data: "a,,b\n1,,3", creator: stub_record(:user), data_type: "consultation")
    begin
      assert i.headers
    rescue => e
      fail e
    end
  end

  test "records the start time and total number of rows in the csv" do
    stub_document_source
    stub_row_class
    stub_model_class
    i = Import.create(csv_data: consultation_csv_sample, creator: stub_record(:user), data_type: "consultation")
    i.stubs(:row_class).returns(@row_class)
    i.stubs(:model_class).returns(@model_class)
    i.perform
    assert_equal 1, i.total_rows
    assert_equal Time.zone.now, i.import_started_at
  end

  test "#perform records the document source of successfully imported records" do
    stub_document_source
    stub_row_class
    stub_model_class
    i = Import.create!(csv_data: consultation_csv_sample, creator: stub_record(:user), data_type: "consultation")
    i.stubs(:row_class).returns(@row_class)
    i.stubs(:model_class).returns(@model_class)
    DocumentSource.expects(:create!).with(document: @document, url: @row.legacy_url, import: i, row_number: 2)
    i.perform
  end

  test "document version history is recorded in the name of the automatic data importer" do
    i = Import.create!(csv_data: consultation_csv_sample, creator: stub_record(:user), data_type: "consultation")
    i.perform
    e = i.document_sources.map {|ds| ds.document.editions}.flatten.first
    assert_equal [@automatic_data_importer], e.authors
    assert_equal @automatic_data_importer.id, e.versions.first.whodunnit.to_i
  end

  test "#perform records an error if a document has already been imported" do
    DocumentSource.stubs(:find_by_url).with("http://example.com").returns(stub("document source", row_number: 2, import_id: 3))
    Import.use_separate_connection
    Import.delete_all
    ImportError.delete_all
    i = Import.create!(csv_data: consultation_csv_sample("old_url" => "http://example.com"), creator: stub_record(:user), data_type: "consultation")
    i.perform
    assert_equal 1, i.import_errors.count
    assert_match /already imported/, i.import_errors.map(&:message).first
    i.destroy
  end

  test "#perform skips blank rows" do
    blank_row = Hash[minimally_valid_consultation_row.map {|k,v| [k,'']}]
    Import.use_separate_connection
    Import.delete_all
    ImportError.delete_all
    i = Import.create!(csv_data: consultation_csv_sample({}, [blank_row]), creator: stub_record(:user), data_type: "consultation")
    i.perform
    assert_equal [], i.import_errors
    assert_equal 1, i.document_sources.count
    assert_match /blank, skipped/, i.log
    i.destroy
  end

  test 'logs failure if save unsuccessful' do
    stub_document_source
    stub_row_class
    stub_model_class
    @errors = {body: ["required"]}
    @model.stubs(:save).returns(false)
    @model.stubs(:errors).returns(@errors)
    @model.stubs(:attachments).returns([])

    Import.use_separate_connection
    Import.delete_all
    ImportError.delete_all
    i = Import.create(csv_data: consultation_csv_sample,
      creator: stub_record(:user), data_type: "consultation")
    i.stubs(:row_class).returns(@row_class)
    i.stubs(:model_class).returns(@model_class)
    i.perform
    assert_equal 1, i.import_errors.count
    assert_equal 2, i.import_errors[0].row_number
    assert_match /body: required/, i.import_errors[0].message
    i.destroy
  end

  test 'logs failure if unable to parse a date' do
    i = Import.create(csv_data: consultation_csv_sample("opening_date" => "31/10/2012"),
      creator: stub_record(:user), data_type: "consultation")
    i.perform
    assert i.import_errors.find {|e| e[:message] =~ /Unable to parse the date/}
  end

  test 'logs failure if unable to find an organisation' do
    i = Import.create(csv_data: consultation_csv_sample("organisation" => "does-not-exist"),
      creator: stub_record(:user), data_type: "consultation")
    i.perform
    assert i.import_errors.find {|e| e[:message] =~ /Unable to find Organisation/}
  end

  test 'logs failures within attachments if save unsuccessful' do
    stub_document_source
    stub_row_class
    stub_model_class
    @errors = {attachments: ["is invalid"]}
    @model.stubs(:save).returns(false)
    @model.stubs(:errors).returns(@errors)
    attachment = stub('attachment', errors: stub('attachment-errors', full_messages: 'attachment error'))
    attachment.stubs(:valid?).returns(false)
    attachment.stubs(:attachment_source).returns(stub('attachment-source', url: 'url'))
    @model.stubs(:attachments).returns([attachment])

    i = Import.create(csv_data: consultation_csv_sample,
      creator: stub_record(:user), data_type: "consultation")
    i.stubs(:row_class).returns(@row_class)
    i.stubs(:model_class).returns(@model_class)
    i.perform
    assert_equal 1, i.import_errors.size
    assert_equal 2, i.import_errors[0][:row_number]
    assert_match /Attachment 'url': attachment error/, i.import_errors[0][:message]
  end

  test 'logs errors for exceptions' do
    stub_document_source
    stub_row_class
    stub_model_class
    @model.stubs(:save).raises("Something awful happened")

    i = Import.create(csv_data: consultation_csv_sample,
      creator: stub_record(:user), data_type: "consultation")
    i.stubs(:row_class).returns(@row_class)
    i.stubs(:model_class).returns(@model_class)
    i.perform
    assert_equal 1, i.import_errors.size
    assert_equal 2, i.import_errors[0][:row_number]
    assert_match /Something awful happened/, i.import_errors[0][:message]
  end

  test 'bad data is rolled back, but import is saved' do
    stub_document_source
    stub_row_class
    stub_model_class
    data = consultation_csv_sample({}, [{'title' => '', 'old_url' => 'http://example.com/invalid'}])
    Import.use_separate_connection
    Import.delete_all
    Import.transaction do
      i = Import.create(csv_data: data, creator: stub_record(:user), data_type: "consultation")
      i.perform
      assert_equal 1, Import.count, "Import wasn't saved correctly"
      assert_equal 0, Consultation.count, "Imported rows weren't rolled back correctly"
      # roll back changes to the import record to ensure we don't leave test data lying around
      raise ActiveRecord::Rollback
    end
  end

private
  def stub_document_source
    DocumentSource.stubs(:find_by_url).returns(nil)
    DocumentSource.stubs(:create!)
  end

  def stub_row_class
    @row = stub('row', attributes: {row: :one}, legacy_url: 'row-legacy-url', valid?: true)
    @row_class = stub('row-class', new: @row, heading_validation_errors: [])
  end

  def stub_model_class
    @document = stub('document')
    @model = stub('model', save: true, document: @document)
    @model_class = stub('model-class', new: @model)
  end

end
