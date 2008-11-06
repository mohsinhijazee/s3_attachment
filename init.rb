# Include hook code here

require 's3_attachment.rb'
require File.dirname(__FILE__) + '/../../../lib/dedomenon.rb'


register_datatype :name => 'madb_s3_attachment', :class_name => 'S3Attachment'
