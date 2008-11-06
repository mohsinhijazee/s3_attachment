require 'S3'

# We define these contants in the model to  minizie the change 
AWS_ACCESS_KEY_ID = '0T89J3VC4461VKA8J182'
AWS_SECRET_ACCESS_KEY = 'yS/e0F/zFwhGt3wcj6+rzmUS4kqOzHZe7qUGTOEd'

# *Description*
#     Contains the S3 Attachment. Stored in the +detail_value+ table.
#     See +DetailValue+ for details.
#     
# *Relationships*
#     * belongs_to :instance
#     * belongs_to :detail   
# 
class S3Attachment < DetailValue
  #FIXME: What to do of it?
  @@base_dir = MadbSettings.s3_local_dir
  # We override this in our production line
  @@base_dir = '/home/modb/apps/dedomenon/shared/system/uploads'
  @@bucket_name = MadbSettings.s3_bucket_name 
  belongs_to :instance
  belongs_to :detail
  serialize :value  #for file_name, mimetype, bucket and key
  
  before_save   :add_s3_key
#  after_save    :save_file
#  after_destroy :destroy_file
  #allow_concurrency = true
        
  def self.table_name
    "detail_values"
  end

  # *Description*
  #   Here we connect to the S3 AWS through the KEY ID and Key
  def initialize(*args)
    super(*args)
     @s3_conn = S3::AWSAuthConnection.new(AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)
  end

  # This returns true always. Just a work around to get ready for the production
  def allows_upload?
    return true
  end

  # Same as before
  def allows_download?
    return true
  end

  def account_id 
    self.instance.entity.database.account_id
  end
  
  def database_id
    self.instance.entity.database_id
  end
  
  def entity_id  
    self.instance.entity_id
  end

  def to_form_row(i=0, o = {})
    #entity_input is used for the id of the input containing the field
    #we need to add random characters to the entity name so scripts generated can distinguish fields in a form
     entity_input = %Q{#{o[:form_id]}_#{o[:entity].name}}.gsub(/ /,"_")
     entity = entity_input+"_"+String.random(3)
		 id = detail.name+"["+i.to_s+"]"
    if allows_upload?
      replace_icon=%Q{<img id="replace_file_#{entity}_#{id}" class="action_cell" src="/images/icon/big/edit.png" alt="replace_file"/>}
      input_field = %Q{<input type="hidden" id="#{o[:entity].name}_#{detail.name}[#{i.to_s}]_id" name="#{detail.name}[#{i.to_s}][id]" value="#{self.id}"><input detail_id="#{detail.id}" class="unchecked_form_value" type="file" id ="#{entity_input}_#{id}_value" name="#{id}[value]"/>}
      undo_icon = %Q{<img onclick="undoFileUpload_#{entity}_#{i}();" id="undo_file_#{entity}_#{id}" class="action_cell" src="/images/icon/big/undo.png" alt="undo_replace_file"/>}
     upload_file_function = %Q{function displayFileUpload_#{entity}_#{i}(e, reversible)
       {
         file_cell = $('#{entity}_#{id}_cell');
            YAHOO.madb.container["#{entity}_#{id}_original_value"] = file_cell.innerHTML;
            YAHOO.util.Event.addListener("undo_file_#{entity}_#{id}",'click',undoFileUpload_#{entity}_#{i});
            var content = '#{input_field}';
            if (reversible)
            {
              content=content+'#{undo_icon}';
            }
            file_cell.innerHTML= content;
            YAHOO.madb.upload_field_tooltips_#{entity}_#{i}();
            YAHOO.madb.hide_current_file_tooltips_#{entity}_#{i}();
       }
       }
    else
      replace_icon="#{self.class.no_transfer_allowed_icon}"
      input_field ="#{self.class.no_transfer_allowed_icon}"
     upload_file_function = %Q{function displayFileUpload_#{entity}_#{i}(e, reversible)
       {
         file_cell = $('#{entity}_#{id}_cell');
         file_cell.innerHTML= '<img src="/images/icon/big/error.png" alt="no_upload" id="no_upload_icon_#{entity}_#{id}">';
         new YAHOO.widget.Tooltip("no_upload_tooltip_#{entity}_#{id}", {  
                       context:"no_upload_icon_#{entity}_#{id}",  
                       text:YAHOO.madb.translations['madb_file_transfer_quota_reached'], 
                       showDelay:100,
                       hideDelay:100,
                       autodismissdelay: 20000} ); 

         }
       }
    end
     #idof the hidden field containing the id of this detail_value, used later in the javascript to reset the value of the hidden field whe we delete the attachment.
     hidden_field_id = %Q{#{o[:entity].name}_#{detail.name}[#{i.to_s}]_id} 
     if value.nil?
      return %Q{<tr><td>#{detail.name}:</td><td id="#{entity}_#{id}_cell">#{input_field}</td></tr> }
     else
      return %Q{
      <tr><td>#{detail.name}:</td><td id="#{entity}_#{id}_cell">#{value[:filename]}<img id="delete_file_#{entity}_#{id}" class="action_cell" src="/images/icon/big/delete.png" alt="delete_file"/>#{replace_icon}</td></tr><script type="text/javascript">

  YAHOO.madb.upload_field_tooltips_#{entity}_#{i} =  function() {
      YAHOO.madb.undo_tooltip_#{entity}_#{i} = new YAHOO.widget.Tooltip("undo_file_tooltip_#{entity}_#{id}", {  
           context:"undo_file_#{entity}_#{id}",  
           text:YAHOO.madb.translations['madb_go_back_do_no_replace_current_file'], 
           showDelay:100,
           hideDelay:100,
           autodismissdelay: 20000} ); 
  }

  YAHOO.madb.hide_current_file_tooltips_#{entity}_#{i} =  function() { 
      YAHOO.madb.delete_tooltip_#{entity}_#{i}.hide();
      YAHOO.madb.replace_tooltip_#{entity}_#{i}.hide();
  }

  YAHOO.madb.hide_upload_field_tooltips_#{entity}_#{i} =  function() { 
      YAHOO.madb.undo_tooltip_#{entity}_#{i}.hide();
  }

  YAHOO.madb.current_file_tooltips_#{entity}_#{i} =  function() { 
      YAHOO.madb.delete_tooltip_#{entity}_#{i} = new YAHOO.widget.Tooltip("delete_file_tooltip_#{entity}_#{id}", {  
           context:"delete_file_#{entity}_#{id}",  
           text:YAHOO.madb.translations['madb_delete_file'], 
           showDelay:100,
           hideDelay:100,
           autodismissdelay: 20000} ); 
      YAHOO.madb.replace_tooltip_#{entity}_#{i} = new YAHOO.widget.Tooltip("replace_file_tooltip_#{entity}_#{id}", {  
           context:"replace_file_#{entity}_#{id}",  
           text:YAHOO.madb.translations['madb_replace_file'], 
           showDelay:100,
           hideDelay:100,
           autodismissdelay: 20000} ); 
  }
  YAHOO.madb.current_file_tooltips_#{entity}_#{i}();

   YAHOO.util.Event.addListener("replace_file_#{entity}_#{id}",'click',displayFileUpload_#{entity}_#{i}, true);
   YAHOO.util.Event.addListener("delete_file_#{entity}_#{id}",'click',delete_file_#{entity}_#{i});

  function delete_file_#{entity}_#{i}()
  {
    dojo.io.bind({
        url: "#{o[:controller].url_for(:controller => "detail_values", :action =>"delete", :id => self.id )}",
        load: function(type, data, evt)
        { 
          displayFileUpload_#{entity}_#{i}(null, false);
          if (document.getElementById('#{hidden_field_id}')!=null) 
            {
              document.getElementById('#{hidden_field_id}').setAttribute('value','');
            }
        },
            
        error: function(type, error){ alert(error.message) },
        mimetype: "text/plain"
    });

  }
  #{upload_file_function}
   function undoFileUpload_#{entity}_#{i}()
     {
          $('#{entity}_#{id}_cell').innerHTML =           YAHOO.madb.container["#{entity}_#{id}_original_value"];
          YAHOO.util.Event.addListener("replace_file_#{entity}_#{id}",'click',displayFileUpload_#{entity}_#{i}, true);
          YAHOO.util.Event.addListener("delete_file_#{entity}_#{id}",'click',delete_file_#{entity}_#{i});
          YAHOO.madb.current_file_tooltips_#{entity}_#{i}();
          YAHOO.madb.hide_upload_field_tooltips_#{entity}_#{i}();
     }
     </script>
      }
     end
    #else #no transfer allowed
    #  return %Q{<tr><td>#{detail.name}:</td><td id="#{entity}_#{id}_cell">#{value ? value[:filename] : ""}#{self.class.no_transfer_allowed_icon}</td></tr> }
    #end
	end

  def self.format_detail(options)
    return "" if options[:value].nil?
    options[:format] = :html if options[:format].nil?
    begin
      o = YAML.load(options[:value])
    rescue TypeError,ArgumentError
      o= options
    end
    case options[:format]
    when :html
       detail_value_id = o[:s3_key].scan(/([^\/]+)/).last[0]
       #generator = S3::QueryStringAuthGenerator.new(AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)
       #generator.expires_in = 60
       #url = generator.get(@@bucket_name, o[:s3_key])
       v = self.find(detail_value_id)
       if v.allows_download?
        url=options[:controller].url_for :controller => 'file_attachments', :action => 'download', :id => detail_value_id
        return %Q{<a href="#{url}">#{html_escape(o[:filename])}</a>}
       else
          html_escape(o[:filename])+self.no_transfer_allowed_icon
       end
    when :first_column
      return o[:filename]
    when :csv
      return o[:filename]
    end
  end

  def self.no_transfer_allowed_icon
    img_id = String.random(8)
    %Q{<img src="/images/icon/big/error.png" id="#{img_id}" alt="quota_reached">
    <script type="text/javascript">
      new YAHOO.widget.Tooltip("tooltip_#{img_id}", {  
           context:"#{img_id}",  
           text:YAHOO.madb.translations['madb_file_transfer_quota_reached'], 
           showDelay:100,
           hideDelay:100,
           autodismissdelay: 20000} ); 
    </script>
    }
  end

  def size
     @s3_conn = S3::AWSAuthConnection.new(AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)
    @s3_conn.head(@@bucket_name, s3_key).http_response.content_length
  end
  
  def download_url
     #debugger
     o = value
     generator = S3::QueryStringAuthGenerator.new(AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)
     generator.expires_in = 60
     return generator.get(@@bucket_name, s3_key)
  end

  def value=(v)
    @attachment = v
    #v.size
    h = { :filename => File.basename(v.original_filename), :filetype => v.content_type, :uploaded => false}
    write_attribute(:value, h)
    puts "File size: #{v.size}"
    puts self.value.to_json
  end

  
  
  # *Description*
  # This method is a callback called before saving. It adds
  # the S3 Key 
  def add_s3_key
    o = value
    o[:s3_key] = s3_key
    write_attribute(:value, o)
  end
  
  # *Description*
  #  Called by the +save_file()+ callback in order to make a local copy
  def make_local_backup
  return true
    @attachment.rewind
    if !FileTest.directory?( local_instance_path )
      FileUtils.mkdir_p( local_instance_path )
    end
    File.open("#{local_instance_path}/#{self.id.to_s}", "w") { |f| f.write(@attachment.read) }
  end
  
  # *Description*
  #  Callback to put the file on S3
  #
#  def save_file
#    debugger
#    make_local_backup
#     @attachment.rewind
#     @s3_conn = S3::AWSAuthConnection.new(AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)
#     options = { 'Content-Type' => @attachment.content_type, "Content-Length" => @attachment.size.to_s, "Content-Disposition"=> "attachment;filename=\"#{@attachment.original_filename}\"" }
#     res = @s3_conn.put(@@bucket_name, s3_key, @attachment.read, options)
#     
#     return false if !res
#     if res.http_response.code!= "200" or res.http_response.message != "OK"
#       #we have a problem
#       return false
#       raise StandardError.new("S3 error. Response code: #{res.http_response.code} and message: #{res.http_response.message}")
#     end
#      
#   return true
#  end
  
    alias _save save
  
  def save
    # debugger
     _save
     o = value
     o[:s3_key] = s3_key
     value_will_change!
     value = o
     _save
     
     make_local_backup

     @attachment.rewind
     @s3_conn = S3::AWSAuthConnection.new(AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)
     res = @s3_conn.put(@@bucket_name, s3_key, @attachment.read, { 'Content-Type' => @attachment.content_type, "Content-Length" => @attachment.size.to_s, "Content-Disposition"=> "attachment;filename=\"#{@attachment.original_filename}\"" })
     if res.http_response.code!= "200" or res.http_response.message != "OK"
       #we have a problem
       raise StandardError.new("S3 error. Response code: #{res.http_response.code} and message: #{res.http_response.message}")
     end
      #t = Transfer.new( :detail_value_id => id , :instance => instance, :entity_id => instance.entity_id, :account_id => instance.entity.database.account_id, :user => nil, :size => @attachment.size, :file => @attachment.original_filename, :direction => 'to_server' )
      #t.save
      detail.database.account.increment(:attachment_count).save
  end
  
  def destroy
    super
    begin
    @s3_conn ||= S3::AWSAuthConnection.new(AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)
    @s3_conn.delete(@@bucket_name,s3_key)
    File.delete(local_instance_path+"/"+self.id.to_s)
    rescue Exception => e
      #breakpoint "exeption in destroy"
    end
      detail.database.account.decrement(:attachment_count).save
  end
  
  def instance_prefix
      %Q{#{account_id}/#{database_id}/#{entity_id}/#{instance_id}}
  end

  def s3_key
    %Q{#{instance_prefix}/#{id}}
  end

  def local_instance_path
    %Q{#{@@base_dir}/#{instance_prefix}}
  end

  def self.valid?(v, o )
    
    # Same as for allows_upload? and allows_download? methods
    #account = o[:entity].database.account
    #return false if (v and v.size > account.account_type.maximum_file_size) or !account.allows_upload?
    return true
  end

end
