require 'rubygems'
require 'sinatra'

configure :production do
  # Configure stuff here you'll want to
  # only be run at Heroku at boot

  # TIP:  You can get you database information
  #       from ENV['DATABASE_URI'] (see /env route below)
end

get '/s3fix' do
  connection = AWS::S3::Base.establish_connection!(
    :access_key_id     => 'AKIAISZJ7YPZRSTF6LQQ',
    :secret_access_key => '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'
  )

  count = 0;
  bucket = AWS::S3::Bucket.find("/stylelist-assets/")
  bucket.each do |file|
    p count.to_s << ". checking " << file.key
    if (!file.metadata['Cache-Control'] && file.key != '/')
      p count.to_s << ". updating " << file.key
      file.metadata['Cache-Control'] = 'max-age=86400'
      file.save
    else
      p count.to_s << ". skipping " << file.key
    end
    count+=1
  end
end