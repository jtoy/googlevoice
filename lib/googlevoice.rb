require 'rubygems'
require 'mechanize'
require 'nokogiri'
require 'json'
class GoogleVoice
  BASE = "https://www.google.com/voice/"
  def initialize(u, p)
    @u,@p = u,p
  end
  
  def login
    agent = WWW::Mechanize.new

    agent.post("https://www.google.com/accounts/ServiceLoginAuth?service=grandcentral",:Email => @u, :Passwd => @p)
    page = agent.get('http://www.google.com/voice/')
 
    dialing_form = page.forms.find {|f| f.has_field?('_rnr_se') }
 
    raise "Login failed" unless dialing_form
    @auth_token = dialing_form.field_with(:name => '_rnr_se').value
    @options = {:_rnr_se => @auth_token}
    @agent = agent
  end

  def logged_in?
    !@agent.nil?
  end
  
  
  #returns the number that is used as the forward_number most often
  def most_frequently_used_number
    JSON.parse(Nokogiri::XML(@agent.get(BASE+'inbox/recent/placed/').body).at('json').inner_text)
  end
  
  def cancel number, forward_number
    
  end
  
  
  #json of your phones
  def phones
    login unless logged_in?
    JSON.parse(Nokogiri::XML(@agent.get(BASE+'contacts').body).at('json').inner_text)['phones']
  end
  
  def agent
    @agent
  end
  
  def call number,forward_number=default_number
    login unless logged_in?
    @agent.post(BASE+'call/connect/', @options.merge(:outgoingNumber => number,:forwardingNumber => forward_number))
  end
  
  def smses
    login unless logged_in?
    JSON.parse(Nokogiri::XML(@agent.get(BASE+'inbox/recent/sms/').body).at('json').inner_text)
  end
  
  
  def text number, text
    login unless logged_in?
    @agent.post(BASE+'sms/send/',@options.merge(:text => text,:phoneNumber => number))
  end
  
  def enable number
    
  end
  
  def disable number
    
  end
  
  def phones
    
  end
  
  def logout
    if @agent
      @agent.get("https://www.google.com/voice/account/signout")
      @agent = nil
    end
    self
  end
  
  
  private
  
  def cached_json
    
  end

end
