module UploadsControllerHelper
  private

  def send_upload(path, options = {})
    if upload_exists?(path)
      if options[:public]
        expires_in(Whitehall.default_cache_max_age, public: true)
      else
        response.headers['Cache-Control'] = 'no-cache, max-age=0, private'
      end

      if mime_type = mime_type_for(path)
        send_file path, type: mime_type_for(path), disposition: 'inline'
      else
        send_file path, disposition: 'inline'
      end
    else
      redirect_to_placeholder(path)
    end
  end

  def redirect_to_placeholder(path)
    if ['.jpg', '.jpeg', '.png'].include?(File.extname(path))
      redirect_to view_context.path_to_image('thumbnail-placeholder.png')
    else
      redirect_to placeholder_url
    end
  end

  def mime_type_for(path)
    Mime::Type.lookup_by_extension(File.extname(path).from(1))
  end

  def upload_exists?(path)
    full_path = File.expand_path(path)
    File.exists?(full_path) && full_path.starts_with?(Whitehall.clean_upload_path.to_s )
  end
end