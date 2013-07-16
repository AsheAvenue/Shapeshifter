require 'rubygems'
require 'fog' #used for listening to SQS
require 'aws/s3' #used for saving to s3
require 'yaml'
require 'logger'
require 'open-uri'
require 'RMagick'
include Magick

# open the config file
config = YAML::load(File.open(File.join(File.dirname(__FILE__), "config.yml")))

QUEUE_URL               = config['sqs_url']
QUEUE_ACCESS_KEY_ID     = config['sqs_access_key_id']
QUEUE_SECRET_ACCESS_KEY = config['sqs_secret_access_key']
ACCOUNT                 = 'noisey'
WIDTH                   = 200
HEIGHT                  = 200
SIZE_KEY                = "_vice_#{WIDTH}x#{HEIGHT}"

# get the images
images = Array.new
image_list = File.open("image_list.txt").read
image_list.each_line do |line|
  images << line.gsub(/\s+/, ' ').strip
end

Message = Struct.new(:account, :image, :width, :height, :size_key)

sqs = Fog::AWS::SQS.new({
  :aws_access_key_id        => QUEUE_ACCESS_KEY_ID,
  :aws_secret_access_key    => QUEUE_SECRET_ACCESS_KEY
})

images.each do |image|
  message = Message.new(ACCOUNT, image, WIDTH, HEIGHT, SIZE_KEY)
  serialized_message = YAML::dump(message)
  sqs.send_message(QUEUE_URL, serialized_message)
  puts "---- Requesting image resize: #{image} to #{WIDTH}x#{HEIGHT} ----"
end