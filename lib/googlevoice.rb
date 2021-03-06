require 'rubygems'
require 'mechanize'
require 'nokogiri'
require 'json'
require 'ostruct'
class GoogleVoice
  BASE = "https://www.google.com/voice/"
  
  
  #TODO get rid of these kludgy global variables
  def self.agent
    @@agent
  end
  def self.options
    @@options
  end
  def agent
    @agent
  end
  
  def initialize(u, p)
    @u = u
    @p = p
  end
  RECENT = BASE + 'inbox/recent/'
  FEEDS = {:all => RECENT+'all/', :inbox=> RECENT+'inbox/', :missed => RECENT+'missed/',
    :placed => RECENT+'placed/', :received => RECENT+'received/', :recorded => RECENT+'recorded/',
    :sms => RECENT+'sms/', :spam => RECENT+'spam/', :starred => RECENT+'starred/',
    :trash => RECENT+'trash/', :voicemail => RECENT+'voicemail/'}
  
  def login
    agent = WWW::Mechanize.new

    page = agent.get('http://www.google.com/voice/')
    form = page.forms.first
    form.Email = @u
    form.Passwd = @p
    page = agent.submit form
 
    dialing_form = page.forms.find {|f| f.has_field?('_rnr_se') }
 
    raise LoginError,"Login failed" unless dialing_form
    @auth_token = dialing_form.field_with(:name => '_rnr_se').value
    @options = {:_rnr_se => @auth_token}
    @@options = @options
    @agent = agent
    @@agent = @agent
  end

  def logged_in?
    !@agent.nil?
  end
  
  
  #returns the number that is used as the forward_number most often
  def most_frequently_used_number
    JSON.parse(Nokogiri::XML(@agent.get(BASE+'inbox/recent/placed/').body).at('json').inner_text)
  end
    
  #your google voice number
  def my_number
    settings['primaryDid']
  end
  
  def phones
    login unless logged_in?
    JSON.parse(Nokogiri::XML(@agent.get(BASE+'contacts').body).at('json').inner_text)['phones'].collect do |x|
      Phone.new x.last.merge(:phone_id => x.last['id'],:type_id => x.last['type'] )
    end  
  end
  
  def contacts
    
  end
  
  def settings
    login unless logged_in?
    JSON.parse(Nokogiri::XML(@agent.get(BASE+'contacts').body).at('json').inner_text)['settings']
  end

  
  def call number,forward_number=most_frequently_used_number,remember=false
    login unless logged_in?
    @agent.post(BASE+'call/connect/', @options.merge(
      :outgoingNumber => number,
      :forwardingNumber => forward_number,
      :subscriberNumber=> "undefined",
      :phoneType => 2, #not sure what this exactly does
      :remember => (remember ? 1 : 0)))
  end
  
  def cancel number, forward_number
    login unless logged_in?
    @agent.post(BASE+'voice/call/cancel/ ', @options.merge(:cancelType=>"C2C",:outgoingNumber => number,:forwardingNumber => forward_number))
  end
  
  
  
  def download_voicemails dir="./voicemails"
    FileUtils.mkdir_p dir
    
  end
  
  def received
    login unless logged_in?
    doc = @agent.get(FEEDS[:received])
    json = JSON.parse(Nokogiri::XML(doc.body).at('json').inner_text)['messages']
    json.collect do |k,h|
      History.new h
    end.sort_by{|x| -x.startTime}
  end
  
  def all
    login unless logged_in?
    doc = @agent.get(FEEDS[:all])
    json = JSON.parse(Nokogiri::XML(doc.body).at('json').inner_text)['messages']
    json.collect do |k,h|
      History.new h
    end.sort_by{|x| -x.startTime.to_i}
  end
  
  def smses
    login unless logged_in?
    doc = @agent.get(FEEDS[:sms])
    ids =   JSON.parse(Nokogiri::XML(doc.body).at('json').inner_text)['messages'].keys
    smses = []
    #TODO: we cant search on ids because ids cant begin with numbers,but google doesnt follow standards
    Nokogiri::HTML(doc.body).search('.goog-flat-button.gc-message.gc-message-read').each do |x|
      next unless ids.include?(x['id'])
      x.search('.gc-message-sms-row').each do |sms|
        smses << SMS.new( 
          sms.search('.gc-message-sms-from').inner_text.strip,
          sms.search('.gc-message-sms-text').inner_text.strip,
          sms.search('.gc-message-sms-time').inner_text.strip,
          x['id']
        )

      end
    end
    smses
  end
  
  
  def text number, text
    login unless logged_in?
    @agent.post(BASE+'sms/send/',@options.merge(:text => text,:phoneNumber => number))
  end
  

  
  def logout
    if logged_in?
      @agent.get("https://www.google.com/voice/account/signout")
      @agent = nil
    end
    self
  end
end


class Phone < OpenStruct
  #attributes: 
  # phone_id:  google used id, int (called phoneId from google)
  # phoneNumber: i18n phone number
  # formattedNumber: humanized phone number string
  # we: data dict
  # wd: data dict
  # verified: bool
  # name: string
  # smsEnabled: bool
  # scheduleSet: bool
  # policyBitmask: int
  # weekdayTimes: list
  # dEPRECATEDDisabled: bool
  # weekdayAllDay: bool
  # telephonyVerified: bool
  # weekendTimes: list
  # active: bool
  # weekendAllDay: bool
  # type_id: int  (called type from google)
  # enabledForOthers: bool


  attr_writer :gv

  def active?
    active
  end
  
  def type_name
    case  type_id
    when 2
      "cell"
    when 7
      "gizmo"
    when 3
      "land"
    else
      "unknown"
    end
  end
  
  def to_s
    "#{name} : #{formattedNumber}"
  end
  
  def enable
    gv.post(GoogleVoice::BASE+"settings/editDefaultForwarding/",GoogleVoice.options.merge({:enabled=>1,:phoneId=>phone_id}))
    active = true
  end
  
  def disable
    gv.agent.post(GoogleVoice::BASE+"settings/editDefaultForwarding/",GoogleVoice.options.merge({:enabled=>0,:phoneId=>phone_id}))
    active = false
  end
  
end

class History < OpenStruct
  
end

class Message
  
end

class SMSThread
  
  def smses
    
  end
  
end


class SMS
  attr_reader :from,:message,:sent_at,:sms_id
  def initialize from,message,sent_at,sms_id
    @from=from
    @message = message
    @sent_at = sent_at
    @sms_id = sms_id
  end
  
  def me?
    from == "Me:"
  end
  
  def to_s
    message
  end
end

class LoginError < Exception
end
