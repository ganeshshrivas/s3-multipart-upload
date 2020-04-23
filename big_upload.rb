# install aws-sdk gem
# install pry-nav gem


# ruby big_upload.rb aws-key aws-secret bucket-name file_path
# ARGV[0] = key  ARGV[1] = secret ARGV[2] = bucket-name ARGV[3] = file

require 'pry-nav';
require 'aws-sdk';

puts "Sript started"

# 20MB
PART_SIZE=1024*1024*20

class File
  def each_part(part_size=PART_SIZE)
    yield read(part_size) until eof?
  end
end

s3 = Aws::S3::Client.new(
  region: 'us-east-1',
  credentials: Aws::Credentials.new(ARGV[0],ARGV[1]),
)

filebasename = File.basename(ARGV[3])

key = filebasename

File.open(ARGV[3], 'rb') do |file|
  if file.size > PART_SIZE
    puts "File size over #{PART_SIZE} bytes, using multipart upload..."
    input_opts = {
      bucket: ARGV[2],
      key:    key,
    }  
    mp_response = s3.create_multipart_upload(input_opts)

     total_parts = file.size.to_f / PART_SIZE
     current_part = 1 

    file.each_part do |part|
	    part_response = s3.upload_part({
	      body:        part,
	      bucket:      ARGV[2],
	      key:         key,
	      part_number: current_part,
	      upload_id:   mp_response.upload_id,
	    })  

      percent_complete = (current_part.to_f / total_parts.to_f) * 100 
      percent_complete = 100 if percent_complete > 100 
      percent_complete = sprintf('%.2f', percent_complete.to_f)
      puts "percent complete: #{percent_complete}"
      current_part = current_part + 1 

  	end 


  	 input_opts = input_opts.merge({
        :upload_id   => mp_response.upload_id,
    })   

    parts_resp = s3.list_parts(input_opts)

    input_opts = input_opts.merge(
        :multipart_upload => {
          :parts =>
            parts_resp.parts.map do |part|
            { :part_number => part.part_number,
              :etag        => part.etag }
            end 
        }   
      )   

    mpu_complete_response = s3.complete_multipart_upload(input_opts)
    puts "big file uploaded"
  else
    s3.put_object(bucket: ARGV[2], key: key, body: file)
    puts "Small file uploaded sucessfully"
  end 
end

