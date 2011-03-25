require 'test_helper'

class ContentBlobTest < ActiveSupport::TestCase
  
  fixtures :content_blobs

  def setup
    @testfilename = 'weirdly_named_testfile_to_awkwardly_avoid_conflicts'
    File.new(@testfilename, "w").close
  end

  def teardown
    File.delete @testfilename if File.exists?(@testfilename)
  end
  
  def test_md5sum_on_demand
    blob=content_blobs(:picture_blob)
    assert_not_nil blob.md5sum    
    assert_equal "2288e57a82162f5fd7fa7050ebadbcba",blob.md5sum
  end
  
  def test_uuid_doesnt_change
    blob=content_blobs(:picture_blob)
    blob.uuid="zzz"
    assert_equal "zzz",blob.uuid
    blob.save!
    assert_equal "zzz",blob.uuid
  end
    
  def test_uuid_doesnt_change2
    blob=content_blobs(:picture_blob)
    blob.uuid="zzz"
    blob.save!
    blob=ContentBlob.find(blob.id)
    assert_equal "zzz",blob.uuid
    blob.save!
    blob=ContentBlob.find(blob.id)
    assert_equal "zzz",blob.uuid
  end
  
  def test_regenerate_uuid
    pic=content_blobs(:picture_blob)
    uuid=pic.uuid
    pic.regenerate_uuid
    assert_not_equal uuid,pic.uuid    
  end
  
  def test_file_dump
    pic=content_blobs(:picture_blob)    
    blob=ContentBlob.new(:data=>pic.data_io_object.read)
    blob.save!
    assert_not_nil blob.filepath    
    data=nil
    File.open(blob.filepath,"rb") do |f|
      data=f.read
    end
    assert_not_nil data
    assert_equal data_for_test('file_picture.png'),data
  end
  
#  def test_dumps_file_on_fetch
#    pic=content_blobs(:picture_blob)    
#    pic.regenerate_uuid #makes sure is not there from a previous test    
#    assert !pic.file_exists?
#    assert_equal data_for_test('file_picture.png'),pic.data_io_object.read
#    assert pic.file_exists?
#    assert_equal data_for_test('file_picture.png'),pic.data_io_object.read
#  end

#  def test_file_exists
#    pic=content_blobs(:picture_blob)    
#    pic.regenerate_uuid #makes sure is not there from a previous test
#    assert !pic.file_exists?
#    pic.save!
#    assert pic.file_exists?
#  end

  #checks that the data is assigned through the new method, stored to a file, and not written to the old data_old field
  def test_data_assignment
    pic=content_blobs(:picture_blob)
    pic.save! #to trigger callback to save to file
    blob=ContentBlob.new(:data=>pic.data_io_object.read)
    blob.save!
    blob=ContentBlob.find(blob.id)
    assert_nil blob.data_old
    assert_equal data_for_test('file_picture.png'),blob.data_io_object.read
    
    assert_not_nil blob.filepath
    data=nil
    File.open(blob.filepath,"rb") do |f|
      data=f.read
    end
    assert_not_nil data
    assert_equal data_for_test('file_picture.png'),data
  end  
  
  #simply checks that get and set data returns the same thing
  def test_data_assignment2
    pic=content_blobs(:picture_blob)        
    pic.data=data_for_test("little_file.txt")
    pic.save!
    assert_equal data_for_test("little_file.txt"),pic.data_io_object.read
    
    #put it back, otherwise other tests fail
    pic.data=data_for_test('file_picture.png')
    pic.save!
  end
#  
  def test_will_overwrite_if_data_changes
    pic=content_blobs(:picture_blob)
    pic.save!
    assert_equal data_for_test("file_picture.png"),File.open(pic.filepath,"rb").read
    pic.data=data_for_test("little_file.txt")
    pic.save!
    assert_equal data_for_test("little_file.txt"),File.open(pic.filepath,"rb").read
  end
  
  def test_uuid
    pic=content_blobs(:picture_blob)
    blob=ContentBlob.new(:data=>pic.data_io_object.read)
    blob.save!
    assert_not_nil blob.uuid
    assert_not_nil ContentBlob.find(blob.id).uuid
  end

  def data_for_test filename
    file = "#{RAILS_ROOT}/test/fixtures/files/#{filename}"
    return File.open(file,"rb").read
  end
  
  def test_tmp_io_object
    file_path=File.expand_path(@testfilename) #use the current file
    io_object = File.new(file_path,"r")
    blob=ContentBlob.new(:tmp_io_object=>io_object)
    assert_difference("ContentBlob.count") do
      blob.save!
    end
    
    blob.reload
    assert_not_nil blob.filepath
    assert File.exists?(blob.filepath)
    data=nil
    File.open(blob.filepath,"rb") do |f|
      data=f.read
    end
    io_object.rewind
    io_data = io_object.read
    assert_not_nil data
    assert_equal io_data.to_s,data.to_s
  end
  
  def test_string_io_object
    io_object = StringIO.new("frog")
    blob=ContentBlob.new(:tmp_io_object=>io_object)
    assert_difference("ContentBlob.count") do
      blob.save!
    end
    
    blob.reload
    assert_not_nil blob.filepath
    assert File.exists?(blob.filepath)
    data=nil
    File.open(blob.filepath,"rb") do |f|
      data=f.read
    end
    
    assert_not_nil data
    assert_equal "frog",data.to_s
  end
  
  def test_data_io
    io_object = StringIO.new("frog")
    blob=ContentBlob.new(:tmp_io_object=>io_object)
    blob.save!
    blob.reload
    assert_equal "frog",blob.data_io_object.read
    
    file_path=File.expand_path(@testfilename) #use the current file
    io_object = File.new(file_path,"r")
    blob=ContentBlob.new(:tmp_io_object=>io_object)
    blob.save!
    blob.reload
    io_object.rewind
    assert_equal io_object.read,blob.data_io_object.read
    
    blob=ContentBlob.new(:url=>"http://www.sysmo-db.org/images/sysmo-db-logo-grad2.png")
    blob.save!
    blob.reload
    assert_nil blob.data_io_object
    
    blob=ContentBlob.new
    assert_nil blob.data_io_object
    blob.save!
    assert_nil blob.data_io_object
  end
  
  def test_exception_when_both_data_and_io_object
    io_object = StringIO.new("frog")
    blob=ContentBlob.new(:tmp_io_object=>io_object,:data=>"snake")
    assert_raise Exception do
      blob.save
    end
  end
  
end