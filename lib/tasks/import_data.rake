require 'aws-sdk'
require 'open-uri'
require Rails.root.join('lib', 'import_data.rb')


desc "Fix dahua RTSP URL"
task :fix_dahua_rtsp => :environment do
  Model.where(vendor_id: 23).each do |model|
    @fixed = false
    if model.h264_url && model.h264_url == 'cam/realmonitor'
      model.h264_url = "/realmonitor?channel=1&subtype=1"
      @fixed = true
    end
    if @fixed
      model.save
      m = Model.find(model.id)
      puts " ->>" + m.model
    end
  end
end

desc "Fix recorders data URLs, Resolution, etc"
task :fix_recorders_data => :environment do
  Recorder.all.each do |recorder|
    @fixed = false
    begin
      if recorder.resolution && (recorder.resolution == '' || recorder.resolution == ' ')
        recorder.resolution = "-"
        @fixed = true
      elsif recorder.resolution && (recorder.resolution == 'f' || recorder.resolution == 'unknown' || recorder.resolution == 'UNKNOWN' || recorder.resolution == 'Unknown')
        recorder.resolution = ""
        @fixed = true
      elsif recorder.h264_url && (recorder.h264_url.length < 8 || recorder.h264_url == 'unknown' || recorder.h264_url == 'UNKNOWN' || recorder.h264_url == 'Unknown')
        recorder.h264_url = ""
        @fixed = true
      elsif recorder.jpeg_url && (recorder.jpeg_url.length < 8 || recorder.jpeg_url == 'unknown' || recorder.jpeg_url == 'UNKNOWN' || recorder.jpeg_url == 'Unknown')
        recorder.jpeg_url = ""
        @fixed = true
      elsif recorder.mjpeg_url && (recorder.mjpeg_url.length < 8 || recorder.mjpeg_url == 'unknown' || recorder.mjpeg_url == 'UNKNOWN' || recorder.mjpeg_url == 'Unknown')
        recorder.mjpeg_url = ""
        @fixed = true
      elsif recorder.official_url && (recorder.official_url.length < 8 || recorder.official_url == 'unknown' || recorder.official_url == 'UNKNOWN' || recorder.official_url == 'Unknown')
        recorder.official_url = ""
        @fixed = true
      end
    rescue => e
      puts e.message
    end
    if @fixed
      recorder.save
      r = Recorder.find(recorder.id)
      puts " ->>" + r.model
    end
  end
end


desc "Fix models data URLs, Resoolution, etc"
task :fix_models_data => :environment do
  Model.all.each do |model|
    @fixed = false
    if model.resolution && (model.resolution == '' || model.resolution == ' ')
      model.resolution = "-"
      @fixed = true
    elsif model.resolution && model.resolution == 'f'
      model.resolution = ""
      @fixed = true
    elsif model.h264_url && model.h264_url.length < 8
      model.h264_url = ""
      @fixed = true
    elsif model.jpeg_url && model.jpeg_url.length < 8
      model.jpeg_url = ""
      @fixed = true
    elsif model.mjpeg_url && model.mjpeg_url.length < 8
      model.mjpeg_url = ""
      @fixed = true
    elsif model.manual_url && model.manual_url.length < 8
      model.manual_url = ""
      @fixed = true
    elsif model.official_url && model.official_url.length < 8
      model.official_url = ""
      @fixed = true
    end
    if @fixed
      model.save
      m = Model.find(model.id)
      puts " ->>" + m.model
    end
  end
end


desc "Delete images/document of given model"
task :delete_model_files, [:modelname] => :environment do |t, args|
  model = Model.find_by_model_slug(args[:modelname])
  if model
    Image.where(owner_id: model.id).destroy_all
    Document.where(owner_id: model.id).destroy_all
    puts " - Model files deleted " + model.model_slug
  else
    puts " - Model not found"
  end
end


desc "Import files of given vendor from cambase.io and store in cambase bucket"
task :import_model_files, [:modelname] => :environment do |t, args|
  model = Model.where(model_slug: args[:modelname].to_url).first
  if model
    vendor = Vendor.where(id: model.vendor_id).first
    if vendor
      AWS.config(
        :access_key_id => ENV['AWS_ACCESS_KEY_ID'], 
        :secret_access_key => ENV['AWS_SECRET_ACCESS_KEY'],
        # disable this key if source bucket is in US
        :s3_endpoint => 's3-eu-west-1.amazonaws.com'
      )
      s3 = AWS::S3.new
      puts "\n //" + vendor.vendor_slug + "//" + model.model_slug
      s3.buckets['cambase.io'].objects.with_prefix('Google drive/').each do |obj|
        info = obj.key.split('/')
        #puts "\n   //" + obj.key + " - " + info.size.to_s
        next if info.size < 4
        model_name = info[2]
        file_name = File.basename(obj.key)
        next if !(model.model_slug.downcase == model_name.downcase)
        
        begin
          temp_file = Tempfile.new(file_name.split(/(.\w+)$/))
          temp_file.binmode
          temp_file.write(obj.read)
          puts "\n >> " + model.model_slug
          
          if File.extname(info.last) == ".jpg" || File.extname(info.last) == ".jpeg" || File.extname(info.last) == ".png" || File.extname(info.last) == ".gif" || File.extname(info.last) == ".tif" || File.extname(info.last) == ".tiff"
            image = Image.create(:file => temp_file)
            if (model.images.append(image))
              puts "  + " + "/" + vendor.vendor_slug + "/" + model_name + "/" + info.last
            else
              puts "  - " + "/" + vendor.vendor_slug + "/" + model_name + "/" + info.last + " ? " + image.file_content_type
            end
          elsif File.extname(info.last) == ".pdf"
            document = Document.create(:file => temp_file)
            model.documents.append(document)
            puts "  + " + "/" + vendor.vendor_slug + "/" + model_name + "/" + info.last
          end
        rescue => e
          puts "ERR: " + e.message
        ensure # ensure we don't keep dead links
          temp_file.close
          temp_file.unlink
        end
      end
    end
  end

  puts " - Model files imported from AWS S3 to database \n"
end


desc "Delete images/document of given vendor"
task :delete_vendor_files, [:vendorname] => :environment do |t, args|
  AWS.config(
    :access_key_id => ENV['AWS_ACCESS_KEY_ID'], 
    :secret_access_key => ENV['AWS_SECRET_ACCESS_KEY'],
    # disable this key if source bucket is in US
    :s3_endpoint => 's3-eu-west-1.amazonaws.com'
  )
  s3 = AWS::S3.new
  s3.buckets['cambase.io'].objects.with_prefix('Google drive/').each do |obj|
    info = obj.key.split('/')
    if info.size == 4
      vendor_name = info[1]
      model_name = info[2]
      file_name = File.basename(obj.key)

      vendor = Vendor.where(vendor_slug: vendor_name.to_url).first
      if vendor
        next if !(vendor.vendor_slug.downcase == args[:vendorname].downcase)

        model = Model.where(model_slug: model_name.to_url, vendor_id: vendor.id).first
        if model
          puts "  x " + model_name + "/" + info.last
          Image.where(:owner_id => model.id).destroy_all
          Document.where(:owner_id => model.id).destroy_all
        end
      end
    end
  end
  puts " Vendor files deleted \n"
end


desc "Download images of given vendor from cambase.io and store in cambase bucket"
task :import_vendor_files, [:vendorname] => :environment do |t, args|
  AWS.config(
    :access_key_id => ENV['AWS_ACCESS_KEY_ID'], 
    :secret_access_key => ENV['AWS_SECRET_ACCESS_KEY'],
    # disable this key if source bucket is in US
    :s3_endpoint => 's3-eu-west-1.amazonaws.com'
  )
  s3 = AWS::S3.new
  s3.buckets['cambase.io'].objects.with_prefix('Google drive/').each do |obj|
    info = obj.key.split('/')
    if info.size == 4
      ### looping through /vendors/models/files
      vendor_name = info[1]
      model_name = info[2]
      file_name = File.basename(obj.key)
      vendor = Vendor.where(vendor_slug: vendor_name.to_url).first
      if vendor
        ## put vendor slug filter here
        next if !(vendor.vendor_slug.downcase == args[:vendorname].downcase)
        #next if (vendor.vendor_slug.downcase == 'TP-Link'.downcase || vendor.vendor_slug.downcase == 'Flir'.downcase || vendor.vendor_slug.downcase == 'Dericam'.downcase || vendor.vendor_slug.downcase == 'Compro'.downcase || vendor.vendor_slug.downcase == 'Canon'.downcase || vendor.vendor_slug.downcase == 'Beward'.downcase || vendor.vendor_slug.downcase == 'Basler'.downcase || vendor.vendor_slug.downcase == 'ABS'.downcase || vendor.vendor_slug.downcase == 'ABUS'.downcase || vendor.vendor_slug.downcase == 'Ubiquiti'.downcase || vendor.vendor_slug.downcase == 'Sony'.downcase || vendor.vendor_slug.downcase == 'Samsung'.downcase || vendor.vendor_slug.downcase == 'Dallmeier'.downcase || vendor.vendor_slug.downcase == 'Dahua'.downcase || vendor.vendor_slug.downcase == 'Afreey'.downcase)
        
        model = Model.where(model_slug: model_name.to_url, vendor_id: vendor.id).first
        if model
          ## put model slug filter here
          #next if !(model.model_slug.downcase == 'n3011-c'.downcase)
          begin
            temp_file = Tempfile.new(file_name.split(/(.\w+)$/))
            temp_file.binmode
            temp_file.write(obj.read)
            puts "\n >> " + model.model_slug
            
            if File.extname(info.last) == ".jpg" || File.extname(info.last) == ".jpeg" || File.extname(info.last) == ".png" || File.extname(info.last) == ".gif" || File.extname(info.last) == ".tif" || File.extname(info.last) == ".tiff"
              image = Image.create(:file => temp_file)
              if (model.images.append(image))
                puts "  + " + "/" + vendor_name + "/" + model_name + "/" + info.last
              else
                puts "  - " + "/" + vendor_name + "/" + model_name + "/" + info.last + " ? " + image.file_content_type
              end
            elsif File.extname(info.last) == ".pdf"
              document = Document.create(:file => temp_file)
              model.documents.append(document)
              puts "\n  + " + "/" + vendor_name + "/" + model_name + "/" + info.last
            end
          rescue => e
            puts "ERR: " + e.message
          ensure # ensure we don't keep dead links
            temp_file.close
            temp_file.unlink
          end
        end
      end
    end
  end
  puts " Models files downloaded from AWS S3 to database \n"
end


desc "Download images of given vendor from cambase.io and store in cambase bucket"
#task :import_recorder_files, [:vendorname] => :environment do |t, args|
task :import_recorders_images => :environment do
  AWS.config(
    :access_key_id => ENV['AWS_ACCESS_KEY_ID'], 
    :secret_access_key => ENV['AWS_SECRET_ACCESS_KEY'],
    # disable this key if source bucket is in US
    :s3_endpoint => 's3-eu-west-1.amazonaws.com'
  )
  s3 = AWS::S3.new
  s3.buckets['cambase.io'].objects.with_prefix('Recorders/').each do |obj|
    info = obj.key.split('/')
    if info.size == 4
      puts "\n- " + obj.key
      ### looping through /vendors/models/files
      vendor_name = info[1]
      recorder_model = info[2]
      file_name = File.basename(obj.key)
      vendor = Vendor.where(vendor_slug: vendor_name.to_url).first
      if vendor
        puts "  > " + vendor.name
        ## put vendor slug filter here
        #next if !(vendor.vendor_slug.downcase == args[:vendorname].downcase)
        #next if (vendor.vendor_slug.downcase == 'TP-Link'.downcase || vendor.vendor_slug.downcase == 'Flir'.downcase || vendor.vendor_slug.downcase == 'Dericam'.downcase || vendor.vendor_slug.downcase == 'Compro'.downcase || vendor.vendor_slug.downcase == 'Canon'.downcase || vendor.vendor_slug.downcase == 'Beward'.downcase || vendor.vendor_slug.downcase == 'Basler'.downcase || vendor.vendor_slug.downcase == 'ABS'.downcase || vendor.vendor_slug.downcase == 'ABUS'.downcase || vendor.vendor_slug.downcase == 'Ubiquiti'.downcase || vendor.vendor_slug.downcase == 'Sony'.downcase || vendor.vendor_slug.downcase == 'Samsung'.downcase || vendor.vendor_slug.downcase == 'Dallmeier'.downcase || vendor.vendor_slug.downcase == 'Dahua'.downcase || vendor.vendor_slug.downcase == 'Afreey'.downcase)
        puts "  >> " + recorder_model.to_url
        recorder = Recorder.where("lower(recorder_slug)=? and vendor_id=?", recorder_model.to_url, vendor.id).first
        if recorder
          puts "  >>> " + file_name
          ## put recorder slug filter here
          #next if !(recorder.recorder_slug.downcase == 'n3011-c'.downcase)
          begin
            temp_file = Tempfile.new(file_name.split(/(.\w+)$/))
            temp_file.binmode
            temp_file.write(obj.read)

            if File.extname(info.last) == ".jpg" || File.extname(info.last) == ".jpeg" || File.extname(info.last) == ".png" || File.extname(info.last) == ".gif" || File.extname(info.last) == ".tif" || File.extname(info.last) == ".tiff"
              image = Image.create(:file => temp_file)
              if (recorder.images.append(image))
                puts "    + " + "/" + vendor_name + "/" + recorder_model + "/" + info.last
              else
                puts "    - " + "/" + vendor_name + "/" + recorder_model + "/" + info.last + " ? " + image.file_content_type
              end
            elsif File.extname(info.last) == ".pdf"
              document = Document.create(:file => temp_file)
              recorder.documents.append(document)
              puts "\n  + " + "/" + vendor_name + "/" + recorder_model + "/" + info.last
            end
          rescue => e
            puts "ERR: " + e.message
          ensure # ensure we don't keep dead links
            temp_file.close
            temp_file.unlink
          end
        end
      end
    end
  end
  puts " Recorder files downloaded to S3 \n"
end

desc "Import recorders.csv from S3 and save data to database"
task :import_recorders => :environment do
  AWS.config(
    :access_key_id => ENV['AWS_ACCESS_KEY_ID'], 
    :secret_access_key => ENV['AWS_SECRET_ACCESS_KEY'],
    # disable this key if source bucket is in US
    :s3_endpoint => 's3-eu-west-1.amazonaws.com'
  )
  s3 = AWS::S3.new
  object = s3.buckets['cambase.io'].objects['recorders.csv']

  puts "\n  Importing recorders.csv from AWS S3 bucket 'cambase.io'... \n"
  File.open("#{Rails.root}/tmp/recorders.csv", "wb") do |f|
    f.write(object.read)
  end
  puts "  'recorders.csv' imported from AWS S3 \n"

  puts "\n  Importing data from 'recorders.csv' to database... \n"
  File.open("#{Rails.root}/tmp/recorders.csv", "r:ISO-8859-15:UTF-8") do |file|
    SmarterCSV.process(file).each do |recorder|
      original_recorder = recorder.clone
      recorder[:vendor_id] = Vendor.where(:vendor_slug => recorder[:vendor].to_url).first_or_create.id
      recorder[:name] = recorder[:model]
      puts "  + " + recorder[:vendor].downcase + "/" + recorder[:name]
      recorder.delete :vendor
      recorder.delete_if { |k, v| v.to_s.empty? }
      recorder[:resolution] = recorder.delete :max_recording_resolution
      recorder[:official_url] = recorder.delete :user_manual
      
      if recorder[:resolution]
        if recorder[:resolution] == '?'
          recorder[:resolution] = ''
        else
          recorder[:resolution] = recorder[:resolution].gsub(/\s+/, "").gsub(/×/, "x").downcase
        end
      end

      recorder.update(recorder){|key,value| clean_csv_values(value)}
      
      r = Recorder.where(:model => recorder[:model]).first_or_initialize
      r.update_attributes(recorder)
      r.attributes.each do |k, v|
        if v == 'f'
          if recorder[k.to_sym]
            r[k.to_sym] = recorder[k.to_sym]
          else
            r[k.to_sym] = 'Unknown'
          end
        end
        r.save
      end
      puts "  #{r.model} \n #{r.errors.messages.inspect} \n\n" unless r.errors.messages.blank?
    end
  end
  puts "  'recorders.csv' imported to database! \n\n"
end


desc "Download images from S3 and save to local directory"
task :import_files_s3_dir => :environment do
  AWS.config(
    :access_key_id => ENV['AWS_ACCESS_KEY_ID'], 
    :secret_access_key => ENV['AWS_SECRET_ACCESS_KEY'],
    :s3_endpoint => 's3-eu-west-1.amazonaws.com'
  )
  s3 = AWS::S3.new
  s3.buckets['cambase.io'].objects.with_prefix('Google drive/').each do |img|
    
    # creating root directory if does not exist
    if Dir.exists?("#{Rails.root}/db/seeds/s3") == false
      Dir.mkdir("#{Rails.root}/db/seeds/s3")
    end

    # dropping 'Google drive/' from path info
    info = img.key.split('/').drop(1)
    if info.size == 1
      # looping through vendors
      if Dir.exists?("#{Rails.root}/db/seeds/s3/" + info[0]) == false
        Dir.mkdir("#{Rails.root}/db/seeds/s3/" + info[0])
        puts "\n  + " + "/s3/" + info[0]
      end
    elsif info.size == 2
      ## looping through vendors/models
      if Dir.exists?("#{Rails.root}/db/seeds/s3/" + info[0] + "/" + info[1]) == false
        Dir.mkdir("#{Rails.root}/db/seeds/s3/" + info[0] + "/" + info[1])
        puts "\n    + " + "/s3/" + info[0] + "/" + info[1]
      end
    elsif info.size == 3
      if File.extname(info.last) == ".jpg" || File.extname(info.last) == ".png" || File.extname(info.last) == ".pdf" || File.extname(info.last) == ".doc" || File.extname(info.last) == ".txt"
        ### looping through vendors/models/files
        filename = "#{Rails.root}/db/seeds/s3/" + info[0] + "/" + info[1] + "/" + info.last
        if File.exist?(filename) == false
          File.open("#{Rails.root}/db/seeds/s3/" + info[0] + "/" + info[1] + "/" + info.last, 'wb') do |file|
            file.write(img.read)
          end
          puts "\n      + " + filename
          
          ###### FOR TESTING ONLY ######
          #break
          ##############################
        end
      end
    end
  end
  puts "  Images downloaded from AWS S3 to #{Rails.root}/db/seeds/s3/ \n"
end


desc "Import master.csv from S3 and save data to database"
task :import_csv_s3_to_db => :environment do
  AWS.config(
    :access_key_id => ENV['AWS_ACCESS_KEY_ID'], 
    :secret_access_key => ENV['AWS_SECRET_ACCESS_KEY'],
    :s3_endpoint => 's3-eu-west-1.amazonaws.com'
  )
  s3 = AWS::S3.new
  object = s3.buckets['cambase.io'].objects['master.csv']

  puts "\n  Importing master.csv from AWS S3 bucket 'cambase.io'... \n"
  File.open("#{Rails.root}/db/seeds/master.csv", "wb") do |f|
    f.write(object.read)
  end
  puts "  'master.csv' imported from AWS S3 \n"
  
  puts "\n  Importing data from 'master.csv' to database... \n"
  Dir.glob("#{Rails.root}/db/seeds/master.csv") do |file|
    SmarterCSV.process(file).each do |model|
      original_model = model.clone
      model[:vendor_id] = Vendor.where(:name => model[:vendor]).first_or_create.id
      ###############
      ## ENABLE next ONLY to import specific vendors' models
      ###############
      next if !(model[:vendor].downcase == 'beward' || 
              model[:vendor].downcase == 'basler' || 
              model[:vendor].downcase == 'canon' ||
              model[:vendor].downcase == 'compro' ||
              model[:vendor].downcase == 'convision' ||
              model[:vendor].downcase == 'dericam' ||
              model[:vendor].downcase == 'flir' ||
              model[:vendor].downcase == 'qvis' ||
              model[:vendor].downcase == 'cnb' ||
              model[:vendor].downcase == 'cp plus')

      puts "\n     + " + model[:vendor].downcase + "." + model[:model]
      model.delete :vendor
      model.delete :optical_zoom
      model.delete :mpeg4_url
      model.delete :audio_url
      model.delete_if { |k, v| v.to_s.empty? }
      model[:manual_url] = model.delete :user_manual
      
      if model[:resolution]
        if model[:resolution] == '?'
          model[:resolution] = ''
        else
          model[:resolution] = model[:resolution].gsub(/\s+/, "").gsub(/×/, "x").downcase
        end
      end

      model.update(model){|key,value| clean_csv_values(value)}
      
      c = Model.where(:model => model[:model]).first_or_initialize
      c.update_attributes(model)
      c.attributes.each do |k, v|
        if v == 'f'
          if model[k.to_sym]
            c[k.to_sym] = model[k.to_sym]
          else
            c[k.to_sym] = 'Unknown'
          end
        end
        c.save
      end
      puts "  #{c.model} \n #{c.errors.messages.inspect} \n\n" unless c.errors.messages.blank?
    end
  end
  puts "  'master.csv' imported to database! \n\n"
end


desc "Download vendor images from cambase.io and store in cambase bucket on S3"
task :import_vendors_images => :environment do
  AWS.config(
    :access_key_id => ENV['AWS_ACCESS_KEY_ID'], 
    :secret_access_key => ENV['AWS_SECRET_ACCESS_KEY'],
    # disable this key if bucket is in US
    :s3_endpoint => 's3-eu-west-1.amazonaws.com'
  )
  s3 = AWS::S3.new
  s3.buckets['cambase.io'].objects.with_prefix('Vendors/').each do |obj|
    info = obj.key.split('/')
    if info.size == 2
      file_name = info[1].split('.').first
      puts "\n> " + file_name
      vendor = Vendor.where(vendor_slug: file_name).first
      if vendor
        puts ">> " + vendor.vendor_slug
        begin
          temp_file = Tempfile.new(file_name.split(/(.\w+)$/), :encoding => 'ascii-8bit')
          temp_file.binmode
          temp_file.write(obj.read)
          vendor.image = Image.create(:file => temp_file)
          puts ">>> Saved" + info[1]
          break
        rescue => e
          puts "ERR: " + e.message
        ensure # ensure we don't keep dead links
          temp_file.close
          temp_file.unlink
        end
      end
    end
  end
  puts " Vendor images downloaded \n"
end


desc "Import Data from Master"
task :import_master => :environment do
  Dir.glob('db/seeds/master.csv') do |file|
    SmarterCSV.process(file).each do |model|
      original_model = model.clone
      model[:vendor_id] = Vendor.where(:name => model[:vendor]).first_or_create.id
      model.delete :vendor
      model.delete :optical_zoom
      model.delete :mpeg4_url
      model.delete :audio_url
      model.delete_if { |k, v| v.to_s.empty? }
      model[:manual_url] = model.delete :user_manual
      
      if model[:resolution]
        if model[:resolution] == '?'
          model[:resolution] = ''
        else
          model[:resolution] = model[:resolution].gsub(/\s+/, "").gsub(/×/, "x").downcase
        end
      end

      model.update(model){|key,value| clean_csv_values(value)}
      c = Model.where(:model => model[:model]).first_or_initialize
      
      c.update_attributes(model)
      c.attributes.each do |k, v|
        if v == 'f'
          if model[k.to_sym]
            c[k.to_sym] = model[k.to_sym]
          else
            c[k.to_sym] = 'Unknown'
          end
        end
        c.save
      end

      puts "#{c.model} \n #{c.errors.messages.inspect} \n\n" unless c.errors.messages.blank?
    end
  end
  puts "\nData Imported from Master CSV to Database! \n\n"
end

desc "Import Data from *.csv"
task :import_csv => :environment do
  Dir.glob('db/seeds/*.csv') do |file|
    SmarterCSV.process(file).each do |model|
      original_model = model.clone
      model.delete :megapixel
      model.delete :framerate
      model.delete :data_sheet
      model.delete :availability
      model.delete :user
      model.delete :mpeg4_url
      model.delete :audio_url
      model.delete :"detailed_shape_/_type_as_in_vendor_catalog"
      model.delete_if { |k, v| v.to_s.empty? }
      model[:official_url] = model.delete :page_reference
      model[:manual_url] = model.delete :user_manual
      model[:sd_card] = model.delete :sd_card_storage
      if model[:audio]
        model[:audio_in] = model.delete :audio
        model[:audio_out] = model[:audio_in]
      end
      if model[:default_user]
        model[:default_username] = model.delete :default_user
      end
      model[:vendor_id] = Vendor.where(:name => model[:manufacturer]).first_or_create.id
      model.delete :manufacturer
      if model[:resolution]
        if model[:resolution] == '?'
          model[:resolution] = ''
        else
          model[:resolution] = model[:resolution].gsub(/\s+/, "").gsub(/×/, "x").downcase
        end
      end

      model.update(model){|key,value| clean_csv_values(value)}
      c = Model.where(:model => model[:model]).first_or_initialize
      c.update_attributes(model)
      c.attributes.each do |k, v|
        if v == 'f'
          if model[k.to_sym]
            c[k.to_sym] = model[k.to_sym]
          else
            c[k.to_sym] = 'Unknown'
          end
        end
        c.save
      end

      puts "#{c.model} \n #{c.errors.messages.inspect} \n\n" unless c.errors.messages.blank?
    end
  end
  puts "\nCSV Import complete! \n\n"
end


desc "Import images"
task :import_images => :environment do
  Dir.foreach('db/seeds/images/') do |folder|
    next if folder == '.' or folder == '..'
    Dir.foreach("db/seeds/images/#{folder}") do |item|
      next if item == '.' or item == '..'
      last_underscore = item.rindex('_')
      model_slug = item[0...last_underscore].to_url
      puts folder
      puts model_slug
      vendor = Vendor.where(:vendor_slug => folder.to_url).first_or_create.id
      model = Model.where(model_slug: model_slug, vendor_id: vendor).first
      if model
        puts "  + " + model
        File.open("db/seeds/images/#{folder}/#{item}") do |f|
          image = Image.create(:file => f)
          model.images.append(image)
        end
      end
      puts
    end
  end
  puts "\nImage Import complete! \n\n"
end


desc "Import documents from google drive"
task :import_documents_from_google_drive => :environment do
  import_documents_from_google_drive
end

desc "Import images from google drive"

task :import_images_from_google_drive => :environment do
  import_images_from_google_drive
end


desc "Downloads csv from google drive"
task :download_csv_from_google_drive => :environment do
  download_csv_from_google_drive
end

desc "Import csv from google drive"

task :import_csv_from_google_drive => :environment do
  import_csv_from_google_drive
end


desc "Import MAC addresses from Evercam"
task :import_mac_addresses => :environment do
  connection = Faraday.new(url: "https://api.evercam.io:443") do |faraday|
    faraday.request :url_encoded
    faraday.adapter Faraday.default_adapter
  end

  response = connection.get "/v1/vendors.json?api_id=3d0e289b&api_key=#{ENV['EVERCAM_KEY']}"

  vendors = JSON.parse(response.body)['vendors']

  vendors.each do |vendor|
    vendor = Vendor.where(vendor_slug: vendor['id']).first
    if vendor
      puts 'known_macs:'
      puts vendor['known_macs'].to_s
      vendor.mac = vendor['known_macs']
      vendor.save
    else
      puts 'no mac addresses for the vendor'
    end
    puts
  end
end
