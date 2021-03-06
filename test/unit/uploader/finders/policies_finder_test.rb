require 'test_helper'

class Whitehall::Uploader::Finders::PoliciesFinderTest < ActiveSupport::TestCase
  def setup
    @log_buffer = StringIO.new
    @log = Logger.new(@log_buffer)
    @line_number = 1
  end

  test "returns the published edition of all documents found by the supplied slugs" do
    policy_1 = create(:published_policy, title: "Policy 1")
    policy_2 = create(:published_policy, title: "Policy 2")
    assert_equal [policy_1, policy_2], Whitehall::Uploader::Finders::PoliciesFinder.find(policy_1.slug, policy_2.slug, @log, @line_number)
  end

  test "returns the draft edition of any documents found by the supplied slugs which have no published editions" do
    policy_1 = create(:published_policy, title: "Policy 1")
    policy_2 = create(:draft_policy, title: "Policy 2")
    assert_equal [policy_1, policy_2], Whitehall::Uploader::Finders::PoliciesFinder.find(policy_1.slug, policy_2.slug, @log, @line_number)
  end

  test "returns the published edition even if a draft edition exists" do
    policy_1 = create(:published_policy, title: "Policy 1")
    policy_1_draft = policy_1.create_draft(create(:user))
    assert_equal [policy_1], Whitehall::Uploader::Finders::PoliciesFinder.find(policy_1.slug, @log, @line_number)
  end

  test "ignores blank slugs" do
    assert_equal [], Whitehall::Uploader::Finders::PoliciesFinder.find('', '', @log, @line_number)
  end

  test "returns an empty array if a document can't be found for the given slug" do
    assert_equal [], Whitehall::Uploader::Finders::PoliciesFinder.find('made-up-policy-slug', @log, @line_number)
  end

  test "logs a warning if a document can't be found for the given slug" do
    Whitehall::Uploader::Finders::PoliciesFinder.find('made-up-policy-slug', @log, @line_number)
    assert_match /Unable to find Document with slug 'made-up-policy-slug'/, @log_buffer.string
  end

  test "returns an empty array if the document for the given slug that cannot be found" do
    assert_equal [], Whitehall::Uploader::Finders::PoliciesFinder.find('made-up-policy-slug', @log, @line_number)
  end

  test "ignores duplicate related policies" do
    policy_1 = create(:published_policy, title: "Policy 1")
    assert_equal [policy_1], Whitehall::Uploader::Finders::PoliciesFinder.find(policy_1.slug, policy_1.slug, @log, @line_number)
  end
end
