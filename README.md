Shapeshifter
============

Shapeshifter is a distributed daemon for resizing mass numbers of images on S3. Its main use case is a scenario in which you have tens of thousands of source images that need to be resized. Launch the daemon on a dozen servers, send the resize messages in via Amazon SQS, and your images will be resized quickly across all the listening daemons.

Setup
============

After cloning, install the following gems:

    $ sudo gem install fog aws-sdk rmagick daemons --no-ri --no-rdoc

Create a config.yml file in the Shapeshifter directory:

    sqs_url: <SQS URL>
    sqs_access_key_id: <SQS Access Key ID> 
    sqs_secret_access_key: <SQS Secret Access Key>
    
    <Account Name>:
      key: <S3 Access Key ID>
      secret: <S3 Secret Access Key>
      bucket: <S3 Bucket>
      
Start the daemon:

    $ ruby shapeshifter_control.rb start
    
The daemon will then watch the SQS queue listed in your config.yml file.


Kicking off the Image Resize process
==============

Shapeshifter expects a YAML object called "Message" to be passed on an SQS message, containing the following keys:

    account: the account name that corresponds to the config.yml S3 account you want to use
    image: the full S3 url (not including the bucket, which is listed in the config.yml) of the base image (the image that'll be resized
    width: the new image width
    height: the new image height
    size_key: the string to be added before the file extension of the new image
    
Put each of those into a YAML structure and then pass them into the SQS queue. In the add_to_queue.rb example we read in a list of images from a file called "image_list.txt," then loop through the images and create a message for each of them:

    images.each do |image|
      message = Message.new(ACCOUNT, image, WIDTH, HEIGHT, SIZE_KEY)
      serialized_message = YAML::dump(message)
      sqs.send_message(QUEUE_URL, serialized_message)
      puts "---- Requesting image resize: #{image} to #{WIDTH}x#{HEIGHT} ----"
    end
    
Legal
==============

© 2013 <a href="http://www.asheavenue.com">Ashe Avenue</a>. Created by <a href="http://twitter.com/timboisvert">Tim Boisvert</a>.
<br />
Shapeshifter is released under the <a href="http://opensource.org/licenses/MIT">MIT license</a>.

