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

#Set up logging
log = Logger.new(File.join(File.dirname(__FILE__), "shapeshifter.log"))
log.level = Logger::INFO
log.info("Shapeshifter process started")       

# create an SQS connection
sqs = Fog::AWS::SQS.new({
  :aws_access_key_id        => QUEUE_ACCESS_KEY_ID,
  :aws_secret_access_key    => QUEUE_SECRET_ACCESS_KEY
})

# Loop control. Trap the TERM and INT signals
_loopflag = true
Signal.trap("TERM") do
  _loopflag = false
end
Signal.trap("INT") do
  _loopflag = false
end

# struct used by SQS message
Message = Struct.new(:account, :image, :width, :height, :size_key)

while _loopflag
  log.debug("Start of Shapeshifter loop")
  health = "good"
  log.debug("Checking SQS for new message")
  begin
    response = sqs.receive_message(QUEUE_URL, {'Attributes' => [], 'MaxNumberOfMessage' => 1 })
    messages = response.body['Message'] 
  rescue Exception => e
    log.error("An exception was thrown while getting SQS message: " + e.message)
    health = "bad"
  end
  if (messages && !messages.empty?)
    log.debug("A message was received from SQS")
    messages.each do |m|
      begin
        
        log.info("Message received from SQS")
        
        # get the message info and split up the body
        body      = YAML::load(m['Body'])
        account   = body[:account]
        image     = body[:image]
        width     = body[:width].to_i
        height    = body[:height].to_i
        size_key  = body[:size_key]
        handle    = m['ReceiptHandle']
        
        log.info("Creating S3 connection")
        
        # create an S3 connection to the bucket
        s3 = AWS::S3.new(
          :access_key_id     => config[account]['key'],
          :secret_access_key => config[account]['secret'])  
        
        # get the bucket  
        bucket = s3.buckets[config[account]['bucket']]
        log.info("Bucket: #{bucket.name}")
        
        # see if the base image currently exists
        log.info("Checking S3 for existing base image: #{image}")
        original = bucket.objects["#{image}"]
        if original && original.exists?
          log.info("Existing base image found")
          
          # figure out the new image size
          new_image = image.dup #use dup so a deep copy of the string is done
          last_instance_of_dot = image.rindex('.')
          new_image[last_instance_of_dot] = "#{size_key}."
    
          #now check to see if the new image size already exists
          log.info("Checking S3 for new image: #{new_image}")
          new_obj = bucket.objects["#{new_image}"]
          if new_obj && new_obj.exists?
            log.info("New image size already exists")
          else
            log.info("Creating new image: #{new_image}")
            
            #download base image
            log.info("Starting by downloading base image")
            original = bucket.objects["#{image}"]
            File.open(File.join(File.dirname(__FILE__), "tmp"), 'wb') do |file|
              original_image = original.read do |chunk|
                file.write(chunk)
              end
            end
            
            #read downloaded image into ImageMagick and resize it
            log.info("ImageMagicking")
            original = Magick::Image.read(File.join(File.dirname(__FILE__), "tmp")).first
            resized = original.resize_to_fill(width, height)
            resized.write(File.join(File.dirname(__FILE__), "new")) do
              self.quality = 70
            end
          
            #create the new object on s3 and upload
            log.info("Uploading new image to S3")
            new_obj = bucket.objects["#{new_image}"]
            file = File.open(File.join(File.dirname(__FILE__), "new"), 'rb')
            new_obj.write(file, :acl => :public_read)
          
            #delete the tmp and new images
            log.info("Deleting local files")
            File.delete(File.join(File.dirname(__FILE__), "tmp"))
            File.delete(File.join(File.dirname(__FILE__), "new"))
          
            #confirm that it exists on s3
            log.info("Confirming that image made it to S3")
            confirmed = bucket.objects["#{new_image}"]
            if confirmed.exists?
              log.info("Image successfully uploaded")
            else
              log.error("New image not uploaded correctly")
              health = "bad"
            end
          end
        else
          log.error("Couldn't find original image")
        end
      rescue Exception => e
        log.error("Error: " + e.message)
        health = "bad"
      end
      
      if health == "good"
        begin
          if (sqs.delete_message(QUEUE_URL, handle))
            log.info("Removed message from SQS")
          else
            log.error("Failed to remove message from SQS. Job may remain in queue")
          end
        rescue Exception => e
          log.error("An exception was thrown while removing the message from SQS: " + e.message)
        end
      else
        log.debug("Health is bad.  Not removing message from SQS")
      end
      
      log.info("------")
      
    end
  else
    log.debug("No message available in SQS")
  end
  log.debug("End of shapeshifter loop")
end
log.info("Shapeshifter process stopped gracefully")