require 'test_helper'

class GooglevoiceTest < Test::Unit::TestCase
  
  def setup
    raise "google voice login credentials not found, you must set gvlogin and gvpassword in your environment" unless ENV['gvlogin'] && ENV['gvpassword']
    @u = ENV['gvlogin']
    @p = ENV['gvpassword']
  end
  
  should "logged_in? be false after logging out" do
    gv = GoogleVoice.new @u,@p
    gv.login
    assert_equal gv.logged_in?, true
    gv.logout
    assert_equal gv.logged_in?, false
  end
  
  should "logged_in? should be false  if never logged in" do
    gv = GoogleVoice.new @u,@p
    assert_equal gv.logged_in?, false
  end
  
  should "be logged_in?" do
    gv = GoogleVoice.new @u,@p
    gv.login
    assert_equal gv.logged_in?, true
  end
  
end
