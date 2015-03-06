BASIC_SAMPLE = ""
namespace :db do
  desc "Fill database with sample data for users and employers"
  #TODO this populate task is no longer maintained. Delete it or make sure it works.
  task :populate => :environment do
     Rake::Task['db:reset'].invoke
     make_intl_location_tags
     make_us_location_tags
     make_au_ca_uk_location_tags
     make_il_and_in_location_tags
     make_position_tags
     make_job_qualifier_tags
     make_skill_tags
     make_basic_users  
     make_sample_us_users
     make_sample_au_ca_uk_users
     make_sample_il_and_in_users
     make_boards
     make_sample_employers # also creates jobs, interviews  
     make_sample_employers("demo") 
     make_configuration
     #fix_location_options
     make_job_ads
     make_system_users
     set_free_plan_for_all_employers
     fix_position_tags_case
     puts "Finished db:populate" 
  end
  
  #task :set_free_plan_for_all_employers => :environment do
  #  set_free_plan_for_all_employers
  #end 
  
  task :make_demo_employers => :environment do
    make_sample_employers("demo")
  end
  
  task :fix_position_tags_case => :environment do
    fix_position_tags_case
  end
  
  task :set_single_share_for_old_shares => :environment do
    Share.update_all(:share_counter => 1)
  end
  
  #task :prioritize_real_jobs => :environment do
  #  prioritize_real_jobs
  #end
  
#  task :set_geotags => :environment do
#    set_geotags
#  end    
  
#  task :set_resume_mandatory => :environment do
#    set_resume_mandatory
#  end
  
#  task :set_locale_to_en => :environment do
#    set_locale_to_en
#  end  
  
#  task :add_au_ca_uk_samples => :environment do
#    load_intl_location_tags
#    make_au_ca_uk_location_tags
#    make_sample_au_ca_uk_users
#  end  

#  task :add_il_and_in_samples => :environment do
#     load_intl_location_tags
#     make_il_and_in_location _tags
#     make_sample_il_and_in_users
#  end  

  
#  task :update_au_ca_uk_geocoding => :environment do
#    update_au_ca_uk_geocoding
#  end  
 
 
 
  # Replaces ALL non @fiveyearitch.com emails with emails of the form
  # anonymized+id#{user.id}@fiveyearitch.com
  #  
  # Run this task after loading production data into staging
  task :make_all_users_sample => :environment do
    make_all_users_sample
  end
  
  task :fix_non_standard_candidates_locations => :environment do
    fix_non_standard_candidates_locations
  end
  
  task :fix_non_standard_jobs_locations => :environment do
    fix_non_standard_jobs_locations
  end  

  # task :group_positions => :environment do
   # group_positions
  # end
  
  # call it like this: bundle exec rake db::add_position_to_group["ruby software engineer","software engineer"] --trace  
  task :add_position_to_group, [:position_name, :add_to_position_name] => :environment do |t, args|
    add_position_to_group(args[:position_name], args[:add_to_position_name])
  end
  
  #task :make_configuration => :environment do
  #  make_configuration
  #end  
  
  #task :fix_location_options => :environment do
  #  fix_location_options
  #end
  
  task :make_boards => :environment do
    make_boards
  end  
  
  #task :make_job_ads => :environment do
  #  make_job_ads
  #end  
  
  #task :make_system_users => :environment do
  #  make_system_users
  #end  
  
  #task :shutdown_all_jobs => :environment do
  #  shutdown_all_jobs
  #end  
  
  #task :drop_google_glass_add_remote => :environment do
  #  Board.where(:name => "google-glass").destroy_all
  #  make_boards
  #end
  
  task :link_existing_ambassadors_to_oauth => :environment do
    link_existing_ambassadors_to_oauth
  end  
end

BASIC_PASSWORD = "__PASSWORD__"
ADMIN_PASSWORD = "__PASSWORD__"
DEMO_PASSWORD = ADMIN_PASSWORD

@location_tags_by_locale = {}
@location_tags_intl = []


def link_existing_ambassadors_to_oauth
  Ambassador.all.each do |ambassador|
    unless ambassador.auth.nil?
      provider = ambassador.provider
      uid = ambassador.uid
      
      auth = Auth.find_by_provider_and_uid(provider, uid)
      auth ||= Auth.new
      
      auth.provider = provider
      auth.uid = uid
      auth.first_name = ambassador.first_name
      auth.last_name = ambassador.last_name
      auth.title = ambassador.title
      auth.profile_links_map = ambassador.profile_links_map
      auth.email = ambassador.email
      auth.avatar = ambassador.avatar
      auth.avatar_content_type = ambassador.avatar_content_type
      auth.save!
      
      ambassador.auth = auth
      ambassador.save!
    end
  end
end 


def build_tags(model, names)
  res = []
  names.each do |tag |
    #puts "Adding #{model.class.name} record: #{tag.to_s}"
    obj = nil
    begin
      obj = model.create!(tag)  
    rescue ActiveRecord::RecordInvalid
      puts "Updating #{model.name} tag: #{tag.to_s}"
      obj = model.find_by_name(tag["name"])
      obj.update_attributes!(tag)
    end
    res << obj
  end
  res
end

def make_intl_location_tags
    locations_intl =CsvParser.file_to_hash(File.dirname(__FILE__) + "/locations_intl.csv" )
    @location_tags_intl  = build_tags(LocationTag, locations_intl)
end

def load_intl_location_tags
  relocation =LocationTag.find_by_name Constants::RELOCATION
  raise "Relocation tag not found" if relocation.nil?
  telecommute=LocationTag.find_by_name Constants::TELECOMMUTE
  raise "Telecommute tag not found" if telecommute.nil?
  @location_tags_intl = [relocation, telecommute]
end

def make_us_location_tags
  make_location_tags(Constants::COUNTRY_US)
end

def make_au_ca_uk_location_tags
  make_location_tags(Constants::COUNTRY_AU)
  make_location_tags(Constants::COUNTRY_CA)
  make_location_tags(Constants::COUNTRY_UK)
end

def make_il_and_in_location_tags
  make_location_tags(Constants::COUNTRY_IL)
  make_location_tags(Constants::COUNTRY_IN)
end

def make_location_tags(country_code)
  locations = CsvParser.file_to_hash(File.dirname(__FILE__) +"/locations_%s.csv" % country_code)
  @location_tags_by_locale[country_code] = (build_tags(LocationTag, locations) + @location_tags_intl)
end

def make_position_tags
  positions = CsvParser.file_to_hash(File.dirname(__FILE__) +'/positions.csv')
   build_tags PositionTag, positions
   group_positions
end

def make_job_qualifier_tags
  jobreq = CsvParser.file_to_hash(File.dirname(__FILE__) +'/jobreq.csv')
    build_tags JobQualifierTag, jobreq
end

def make_skill_tags
  skills = CsvParser.file_to_hash(File.dirname(__FILE__) +'/skills.csv')
  build_tags SkillTag, skills
end

def get_tag_by_name(name, list)
    list.each do |tag|
      if (tag.name.casecmp(name) ==0)
          return tag
       end  
    end
    raise "Cannot find #{name} in #{list}"
end


def make_basic_users  
  usr_JohnDoe = User.new({ :email =>  "pronominate@gmail.com" , :password => BASIC_PASSWORD})
  usr_JohnDoe.sample=true
  usr_JohnDoe.wanted_salary = 120000
  usr_JohnDoe.current_position = PositionTag.find_by_name(".Net/C# Developer".downcase)
  usr_JohnDoe.wanted_position = PositionTag.find_by_name("Android Developer".downcase)
  
  usr_JohnDoe.location = @location_tags_by_locale[Constants::COUNTRY_US].first
  usr_JohnDoe.status = UserConstants::VERIFIED
  usr_JohnDoe.years_in_job = 6
  usr_JohnDoe.locale = Constants::LOCALE_EN
  usr_JohnDoe.save!
  assign_bounding_box(usr_JohnDoe)
  usr_JohnDoe.update_attribute :contact_info,  usr_JohnDoe.email
  
  UserJobQualifier.create!({:user => usr_JohnDoe, :job_qualifier_tag => JobQualifierTag.find_by_id(1)})
  UserJobQualifier.create!({:user => usr_JohnDoe, :job_qualifier_tag => JobQualifierTag.find_by_id(2)})
  UserJobQualifier.create!({:user => usr_JohnDoe, :job_qualifier_tag => JobQualifierTag.find_by_id(3)})  
  UserJobQualifier.create!({:user => usr_JohnDoe, :job_qualifier_tag => JobQualifierTag.find_by_id(4) })
  
  UserSkill.create!({:user => usr_JohnDoe, :skill_tag => SkillTag.find_by_id(1), :seniority => UserSkill::PROFESSIONAL})
  UserSkill.create!({:user => usr_JohnDoe, :skill_tag => SkillTag.find_by_id(2), :seniority => UserSkill::PROFESSIONAL})
  UserSkill.create!({:user => usr_JohnDoe, :skill_tag => SkillTag.find_by_id(3), :seniority => UserSkill::LEARNER})
  UserSkill.create!({:user => usr_JohnDoe, :skill_tag => SkillTag.find_by_id(4), :seniority => UserSkill::PROFESSIONAL})
  UserSkill.create!({:user => usr_JohnDoe, :skill_tag => SkillTag.find_by_id(5), :seniority => UserSkill::EXPERT})  
  
   
  usr_AdonPupkin = User.new({:email => "adonpupkin@gmail.com", :password => BASIC_PASSWORD})
  usr_AdonPupkin.sample=true
  usr_AdonPupkin.status = UserConstants::VERIFIED
  usr_AdonPupkin.wanted_salary = 100000;
  usr_AdonPupkin.current_position =  PositionTag.find_by_id(1)
  usr_AdonPupkin.wanted_position =  PositionTag.find_by_id(PositionTag.count)
  usr_AdonPupkin.location = @location_tags_by_locale[Constants::COUNTRY_US].second
  
  usr_AdonPupkin.years_in_job = 4
  usr_AdonPupkin.locale = Constants::LOCALE_EN
  usr_AdonPupkin.save!
  usr_AdonPupkin.update_attribute :contact_info,  usr_AdonPupkin.email
  assign_bounding_box(usr_AdonPupkin)
  
  UserJobQualifier.create!({:user => usr_AdonPupkin, :job_qualifier_tag => JobQualifierTag.find_by_id(2)})
  UserJobQualifier.create!({:user => usr_AdonPupkin, :job_qualifier_tag => JobQualifierTag.find_by_id(3)})
  
  UserSkill.create!({:user => usr_AdonPupkin, :skill_tag => SkillTag.find_by_id(2), :seniority => UserSkill::PROFESSIONAL})
  UserSkill.create!({:user => usr_AdonPupkin, :skill_tag => SkillTag.find_by_id(6), :seniority => UserSkill::PROFESSIONAL})
 
 
  usr_AmyS = User.new({ :email => "amy.t.savage@gmail.com", :password => BASIC_PASSWORD})
  usr_AmyS.sample=true
  usr_AmyS.status = UserConstants::VERIFIED
  usr_AmyS.wanted_salary = 120000
  usr_AmyS.current_position =  PositionTag.find_by_id(PositionTag.count)
  usr_AmyS.wanted_position = PositionTag.find_by_id(1)
  usr_AmyS.location = @location_tags_by_locale[Constants::COUNTRY_US].second
  usr_AmyS.years_in_job = 6
  usr_AmyS.locale = Constants::LOCALE_EN
  usr_AmyS.save! 
  assign_bounding_box(usr_AmyS)
  usr_AmyS.update_attribute :contact_info,  usr_AmyS.email
  
  UserJobQualifier.create!({:user => usr_AmyS, :job_qualifier_tag => JobQualifierTag.find_by_id(1)})
  UserJobQualifier.create!({:user => usr_AmyS, :job_qualifier_tag => JobQualifierTag.find_by_id(JobQualifierTag.count)})

  UserSkill.create!({:user => usr_AmyS, :skill_tag => SkillTag.find_by_id(1), :seniority => UserSkill::EXPERT})
  
end

def make_sample_au_ca_uk_users
    make_sample_users(Constants::COUNTRY_AU)
    make_sample_users(Constants::COUNTRY_CA)
    make_sample_users(Constants::COUNTRY_UK)
end

def make_sample_il_and_in_users
    make_sample_users(Constants::COUNTRY_IL)
    make_sample_users(Constants::COUNTRY_IN)
end

def make_sample_us_users
  make_sample_users(Constants::COUNTRY_US)
end

def assign_bounding_box(usr)#TODO refactor similar functionality which exists here and in users_controller.rb, and move to user.rb
    if usr.location.coordinates?
      locale = usr.locale
      search_radius_in_miles = I18n.t(:search_radius_in_miles, :locale =>locale ).to_i
      bounding_box = DistanceUtils::bounding_box(usr.location.latitude, usr.location.longitude,search_radius_in_miles )
      usr.assign_attributes(bounding_box, :without_protection => true)
      usr.save!
    end
end
    
def make_sample_users(country_code)
  
  fn = "/sample_users_%s.csv" % country_code
  arr_of_hashes = CsvParser.file_to_hash(File.dirname(__FILE__) + fn)
   
  puts "Error: #{fn} should have lowercase content only " if /[A-Z]/=~arr_of_hashes.to_s 
  arr_of_hashes.each do |hash|
    #Columns are location,position_now,position_wanted,wanted_salary,skill_a,skill_a_yrs,skill_b,skill_b_yrs,skill_c,skill_c_yrs,qualifier_a,qualifier_b,qualifier_c, locale
    usri = User.new({:name => "", :email => Constants::SAMPLE_USER_EMAIL_TEMPLATES[0]  % ""})
    wanted_sal = hash["wanted_salary"]
    
    usri.wanted_salary = 1000 * wanted_sal.to_i
    
    curr_position=hash["position_now"]
    usri.current_position =  PositionTag.find_by_name(curr_position) 
    wanted_position=hash["position_wanted"]
    usri.wanted_position = PositionTag.find_by_name(wanted_position) 

    location = hash["location"]
    
    usri.location = get_tag_by_name(location, @location_tags_by_locale[country_code])

    usri.created_at = rand(60).days.ago - rand(23).hours - rand(59).minutes
    country_code_from_csv = hash["country_code"]
    raise "No country_code found in #{hash} in /sample_users_#{country_code}.csv" if country_code_from_csv.nil? 
    locale = Constants::COUNTRIES[country_code_from_csv]
    puts "Wrong country code \"#{country_code_from_csv}\" for #{hash} in file" "/sample_users_%s.csv" % country_code unless country_code_from_csv == country_code
    raise "No locale found for #{country_code_from_csv} in #{Constants::COUNTRIES}" if locale.nil?
    usri.locale = locale
    usri.save!
    usri.update_attribute :contact_info,  usri.email
     
    assign_bounding_box(usri)


    skill_col_pairs= ["skill_a","skill_b","skill_c"]
    skill_col_pairs.each do |skill|
      skill_from_csv = hash[skill]
      unless skill_from_csv.nil?
        skill_yrs=hash[skill+"_yrs"]
        skilltag = SkillTag.find_by_name(skill_from_csv.downcase) 
        skill_yrs = skill_yrs.to_i 
        puts "Error: non-canonical skill level #{skill_yrs} for #{hash}" unless UserSkill.validate(skill_yrs) 
        UserSkill.create!({:user => usri  , :skill_tag => skilltag, :seniority => skill_yrs})
      end
   end
   
    qual_cols= ["qualifier_a","qualifier_b","qualifier_c"]
    qual_cols.each do |qual_col|
      qual = hash[qual_col]
      unless qual.nil?
        qualtag = JobQualifierTag.find_by_name(qual) 
        UserJobQualifier.create!({:user => usri, :job_qualifier_tag => qualtag})
      end
    end
    
    usr_s = "id #{usri.id} location ID #{usri.location.name}  location #{ location} curr_position ID #{usri.current_position.name} curr_position #{curr_position}"
    #  puts usr_s
  end #usri
end 

 
def make_sample_employers(type = BASIC_SAMPLE)
  arr_of_hashes = CsvParser.file_to_hash(File.dirname(__FILE__) +"/#{type}employers.csv") 
  arr_of_hashes.each do |hash| 
      fn =hash["first_name"]
      ln = hash["last_name"]
      company_name = hash["company_name"]
      full_name_for_li=(fn+ln).downcase
      email= hash["email"]
      
      existing = Employer.find_by_email(email)#This is to delete employers when we run this standalone for making demo users
      existing.destroy if existing
      if type==BASIC_SAMPLE
        pw = BASIC_PASSWORD 
      else
        pw = DEMO_PASSWORD
      end
      
      if email.blank?#Create a sample employer like sample+3@fiveyearitch.com/__PASSWORD__
        email = Constants::SAMPLE_USER_EMAIL_TEMPLATES[0]  % ""
        pw = nil
      end
      
      emplr = Employer.new({
          :email => email,
          :first_name => fn,
          :last_name => ln,
          :li_url => "http://profiles.linkedin.com/#{full_name_for_li}",
          :company_name => company_name,
          :password => pw
        })
      emplr.status = UserConstants::VERIFIED
      emplr.sample = (type==BASIC_SAMPLE)
      age_in_seconds = hash["age_in_seconds"]
      
      emplr.created_at = age_in_seconds ? age_in_seconds.to_i.seconds.ago : rand(60).days.ago - (rand(22)+1).hours - rand(59).minutes # in the past
      emplr.save!
      
      tier=Constants::TIER_BASIC
      plan = emplr.employer_plans.build(:tier => tier, :monthly_price => Utils::monthly_price(tier))
     plan.save!
     # p emplr
     
      make_sample_jobs(emplr, type)#also makes interviews
   end # one emplr
   
    make_sample_ambassadors(type)
end 
 
# Also makes interviews
# Every sample job is created for every employer
def make_sample_jobs(emplr, type)
  idx = 0
  arr_of_hashes = CsvParser.file_to_hash(File.dirname(__FILE__) + "/#{type}jobs.csv")
  arr_of_hashes.each do |hash|
      idx+=1 

      job = Job.new

      locname = hash["location_name"]
      loc = LocationTag.find_by_name(locname)
      raise "location #{locname} not found" if loc.nil?
      job.employer_id =  emplr.id
 
      posname = hash["position_name"]
      pos = PositionTag.find_by_name(posname)
       if pos.nil?
         puts "Creating position #{posname}"
         pos =PositionTag.create!(:name=>posname, :priority=>1)
       end      
 
      job.position_id =  pos.id
      job.description =  hash["description"]
      job.location_id =  loc.id
      job.company_name =  emplr.company_name
      job.ad_url= "http://www.someadshere.com/jobadid=#{idx}"
      job.status =  Job::PUBLISHED
      age_in_seconds = hash["age_in_seconds"]
 
      job.created_at = age_in_seconds ? age_in_seconds.to_i.seconds.ago  : emplr.created_at + rand(3).seconds  
      job.save!
       
    #  p job
      if type==BASIC_SAMPLE # Only make sample interviews for the base samples.
         make_sample_interviews(job)
      end
       
      boards = hash["board_names"]
      if boards && !boards.empty?
        make_boards # Make if needed
 
        boards_arr = boards.split(",")
        boards_arr.each do|brd_name|
          brd_name.strip!
          board = Board.find_by_name brd_name
          raise "Cannot find \"#{brd_name}\"" unless board
          Ad.create!({:board_id=>board.id, :job_id=>job.id})
          
        end 
      end
      
  end # one job
end

#Only the 'demo' ambs are made for now. 
def make_sample_ambassadors(type=BASIC_SAMPLE)
  idx = 0
  ambcsv = File.dirname(__FILE__) + "/#{type}ambassadors.csv"
  
  return unless File.exist?(ambcsv)
  
  arr_of_hashes = CsvParser.file_to_hash(ambcsv)
  arr_of_hashes.each do |hash|
      idx+=1 
      
      # first create an associated auth object
      auth = Auth.new
      auth.first_name = hash["first_name"]
      auth.last_name = hash["last_name"]
      auth.title = hash["title"]
      
      profile_links_s = hash["profile_links_map"]   
      profile_links_hash = ActiveSupport::JSON.decode(profile_links_s)
      
      auth.profile_links_map = profile_links_hash
      
      raise "not a hash {prof_links_s}"  unless profile_links_hash.class == Hash
         
      avatar_file_name =  hash["avatar_file"]
      avatar_file = File.dirname(__FILE__) + "/ambimages/"+ avatar_file_name
      file_contents = File.open(avatar_file, 'rb') { |io| io.read }
      auth.avatar = file_contents
      if avatar_file.end_with? ".png"
        auth.avatar_content_type = "image/png"
      elsif avatar_file.end_with?(".jpg") ||avatar_file.end_with?(".jpeg")
        auth.avatar_content_type = "image/jpeg"
      else
        raise "Unknown type #{avatar_file}" 
      end 
      
      auth.save!
      
      emplr_email = hash["employer_email"]
      emplr = Employer.find_by_email(emplr_email)
      raise "Cannot find employer \"#{emplr_email}\"" unless emplr
      
      # create an ambassador
      ambassador = Ambassador.new
      ambassador.employer_id = emplr.id
      ambassador.status = Ambassador::ACTIVE
      
      ambassador.update_from_oauth!(auth)
   
  end # one amb
end

def make_sample_interviews(job)
     # All the interviews go to employees sample+9@fiveyearitch.com, sample+10@fiveyearitch.com, Amy, Pronominate, and Adon 
     ids = ["pronominate@gmail.com", "adonpupkin@gmail.com","amy.t.savage@gmail.com"].map do|email | 
         User.find_by_email(email).id
     end
            
     ids  << 10 << 11 # sample+9 and sample+10
     
     ids.each do |user_id|
         interview= Interview.new({
          })
          
          raise "Cannot find user #{user_id}" if User.find_by_id(user_id).nil?
          
          interview.user_id = user_id 
          interview.employer_id = job.employer_id
          interview.user_id =  user_id    
          interview.job_id = job.id
 
           interview.status = Interview::CONTACTED_BY_EMPLOYER
          user = User.find_by_id(user_id)
          
          interview.contact_info = user.email
          interview.created_at = job.created_at + 30.seconds
        
          interview.save!
          #p interview
     end # one job
end


LOREM_IPSUM = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Curabitur mollis pretium lobortis. Nunc a neque pretium velit gravida mattis quis a libero. Nunc cursus, nulla _fyi_ ac aliquet rhoncus, eros lorem accumsan nibh, vitae iaculis ipsum tellus ut erat. Class aptent taciti sociosqu ad litora torquent per conubia nostra, per inceptos himenaeos."


#def set_geotags
#  arr_of_hashes = CsvParser.file_to_hash(File.dirname(__FILE__) +'/geotags.csv')
#  arr_of_hashes.each do |hash|  
#    location = LocationTag.find_by_name(hash["name"])
#    unless location.nil?
#      location.assign_attributes({ :latitude => hash["latitude"].to_f, :longitude => hash["longitude"].to_f }, :without_protection => true)
#      location.save!
#      
#      location.users.each do |user|
#        bounding_box = DistanceUtils::bounding_box(location.latitude, location.longitude)
#        user.assign_attributes(bounding_box, :without_protection => true)
#        user.save!
#      end
#    end
#  end
#end

#def set_resume_mandatory
#  jobs = Job.all
#  jobs.each do |job|
#    job.update_attribute(:resume_mandatory, false)
#  end
#end

# Replaces ALL non @fiveyearitch.com emails with emails of the form
# sample+id#{user.id}@fiveyearitch.com so that we do not send them email by accident  
def make_all_users_sample
  [User, Employer, Ambassador].each do |model|
    if model.table_exists?
      users = model.all
      users.each do |user|
        unless user.email =~ /.*@#{Constants::FIVEYEARITCH_SITENAME.downcase}$/  || user.email =~ /.*@#{Constants::SITENAME_LC}$/
          user.update_attribute(:email, "anonymized+id#{user.id}@#{Constants::FIVEYEARITCH_SITENAME.downcase}") 
        end
      end
    end
  end
end


#def set_locale_to_en
#  [User, Job].each do |model|
#    objs = model.all
#    objs.each do |obj|
#      obj.update_attribute(:locale, "en") if obj.locale.blank?
#    end
#  end
#end

#def update_au_ca_uk_geocoding
#  update_location_tags(Constants::COUNTRY_AU)
#  update_location_tags(Constants::COUNTRY_CA)
#  update_location_tags(Constants::COUNTRY_UK)
#end

#def update_location_tags(country_code)
#  locations = CsvParser.file_to_hash(File.dirname(__FILE__) +"/locations_%s.csv" % country_code)
#  locations.each do |loc_attrs|
#    puts "Updating location #{loc_attrs["name"]}"
#    loc = LocationTag.find_by_name(loc_attrs["name"])
#    loc.update_attributes!(loc_attrs)
#    
#    loc.users.each do |user|
#      bounding_box = DistanceUtils::bounding_box(loc.latitude, loc.longitude)
#      user.assign_attributes(bounding_box, :without_protection => true)
#      user.save!
#    end
#  end
#end

def fix_non_standard_candidates_locations
  fix_non_standard_locations(:users)
end

def fix_non_standard_jobs_locations
  fix_non_standard_locations(:jobs)
end

def fix_non_standard_locations(for_obj)
   locations = LocationTag.all
   locations.each do |location|
     unless location.latitude.nil? or location.longitude.nil? # We could replace this with  if location.coordinates?
       location.send(for_obj).each do |obj|
         if obj.northmost.nil? or obj.southmost.nil? or obj.westmost.nil? or obj.eastmost.nil?
           bounding_box = DistanceUtils::bounding_box(location.latitude, location.longitude)
           obj.assign_attributes(bounding_box, :without_protection => true)
           obj.save!
           
           puts "Setting #{for_obj} id=#{obj.id} location cordinates to #{location.name}"
         end
       end
     end
   end
end

def group_positions
  hash = CsvParser.file_to_hash(File.dirname(__FILE__) + "/positions_grouping.csv" )
  
  hash.each do |position|
    begin
      family_root = PositionTag.find_by_name(position["family"])
      tag = PositionTag.find_by_name(position["name"])
      if family_root.nil? || tag.nil?
        #skipping
      else
        #puts "Adding \"#{tag.name}\" to \"#{family_root.name}\" group"
        tag.update_attribute(:family_id, family_root.id)
      end
    rescue Exception => exc
      puts "Exception #{exc.message} on #{position.to_s}"
    end
  end
end

def add_position_to_group(what_position_name, to_position_name)
  PositionTag.add_position_to_group(what_position_name, to_position_name)
end

def make_configuration
  FyiConfiguration.delete_all
  
  hash = CsvParser.file_to_hash(File.dirname(__FILE__) + "/configuration.csv" )
  hash.each do |pair|
    begin
      obj = FyiConfiguration.find_or_initialize_by_key(pair[:key])
      obj.update_attributes(pair)
    rescue Exception => exc
      puts "Exception #{exc.message} on #{pair.to_s}"
    end
  end
end

def fix_location_options
  begin
    counter = 0
    
    telecommute_tag = LocationTag.find_by_name(Constants::TELECOMMUTE )
    relocation_tag = LocationTag.find_by_name(Constants::RELOCATION)
    
    tel_users = User.where("location_id = ?", telecommute_tag.id)
    tel_users.each do |u|
      u.can_telecommute = true
      u.location = nil
      u.save!
      counter = counter + 1
    end
    
    rel_users = User.where("location_id = ?", relocation_tag.id)
    rel_users.each do |u|
      u.can_relocate = true
      u.location = nil
      u.save!
      counter = counter + 1
    end  
    
    puts "Fixed #{counter} user locations"
    
    split_mixed_locations_into_options
    
  rescue Exception => exc
    puts "Exception #{exc.message} in fix_location_options"
  end
end

def split_mixed_locations_into_options
  def replace_invalid_location(old_location_name, new_location_name, can_relecommute, can_relocate)
    old_loc = LocationTag.find_by_name(old_location_name)
    new_loc = LocationTag.find_by_name(new_location_name)
    
    if old_loc.nil?
      raise "Location #{old_location_name} not found in database"
    else
      old_loc.users.each do |u|
        u.assign_all_location_attrs(new_loc, can_relecommute, can_relocate)
        u.save!
      end
      old_loc.delete
      
      puts "Location #{old_location_name} was deleted"
    end
  rescue Exception => e
    puts "Warning: #{e.message} in replace_invalid_location"
  end
  
  replace_invalid_location("telecommute,sydney,???", "sydney", true, false)
  replace_invalid_location("princeton, new jersey or remote", "princeton, new jersey", true, false)
  replace_invalid_location("telecommute,pune", "pune", true, false)
  replace_invalid_location("greater boston area, telecommute, or relocate", "boston, massachusetts", true, true)
  replace_invalid_location("telecommute or atlanta" , "atlanta, georgia", true, false)
  replace_invalid_location("atlanta, georgia, athens, ga, telecommute option" , "atlanta, georgia", true, false)
  replace_invalid_location("denver, colorado or telecommute", "denver, colorado", true, false)
  replace_invalid_location("telecommute, bangalore", "bangalore", true, false)
  replace_invalid_location("in or around dc area or telecommute", "washington, washington, d.c.", true, false)
  replace_invalid_location("telecommute or nyc, boston, san francisco, london, munich", "new york, new york", true, true)
  replace_invalid_location("greater boston, telecommute, relo ok", "boston, massachusetts", true, true)
  replace_invalid_location("san diego, california / telecommute", "san diego, california", true, false)
  replace_invalid_location("relocation tennesee", "nashville, tennessee", false, true)
  replace_invalid_location("telecommute, 91801", "los angeles, california", true, false)
  replace_invalid_location("ontario, telecommute", "toronto, ontario", true, false)
  replace_invalid_location("london, reading, relocation, telecommute, seattle", "london", true, true)
  replace_invalid_location("san francisco, telecommute", "san francisco, california", true, false)
  replace_invalid_location("telecommute; chapel hill, nc; or durham, nc", "durham, north carolina", true, false)
  replace_invalid_location("israel", nil, false, true)
end

def make_boards
  hash = CsvParser.file_to_hash(File.dirname(__FILE__) + "/boards.csv" )
  hash.each do |board|
    begin
      obj = Board.find_or_create_by_name(board["name"])
      obj.update_attributes(board)
    rescue Exception => exc
      puts "Exception #{exc.message} on #{board.to_s}"
    end
  end  
end



def make_job_ads
  Ad.delete_all
  make_boards # Make if needed
  boards= Board.all
  expected_num_boards = 6
  raise "There should be #{expected_num_boards} boards, but there are #{boards.length}" if boards.length < expected_num_boards
  idx = 0
  Job.all.each {|job|
    # Deterministic but arbitrary assignment of boards
    case idx
    when 0
      Ad.create!({:board_id=>boards[0].id, :job_id=>job.id})
      Ad.create!({:board_id=>boards[1].id, :job_id=>job.id})
    when 1
      Ad.create!({:board_id=>boards[2].id, :job_id=>job.id})
      Ad.create!({:board_id=>boards[3].id, :job_id=>job.id})
      Ad.create!({:board_id=>boards[4].id, :job_id=>job.id})
    when 2
      Ad.create!({:board_id=>boards[5].id, :job_id=>job.id})
    else
      #This job has no ad (because it has no board)
    end
    
    idx += 1
    idx %= 4 # Iterate through cases 0,1,2,3 above

  }
  
end

def prioritize_real_jobs
  jobs = Job.all
  jobs.each do |job|
    job.update_attribute(:display_order, Job::NORMAL_JOB_DISPLAY_RANK) if job.employer.sample != true and job.display_order == 0
  end
end

def make_system_users
  # Bob - admin
  usr_bob = User.new({:email =>  Constants::ADMIN_CONSOLE__USER, :password => ADMIN_PASSWORD})
  usr_bob.admin=true
  usr_bob.sample=true
  usr_bob.wanted_salary = 200000
  usr_bob.current_position = PositionTag.find_by_name("software engineer")
  usr_bob.wanted_position = PositionTag.find_by_name("software engineer")
  usr_bob.can_relocate = true
  usr_bob.status = UserConstants::DEACTIVATED
  usr_bob.years_in_job = 20
  usr_bob.locale = Constants::LOCALE_EN
  usr_bob.save!
  
  # Jenny Collins - RJ matchmaker
  emplr_jenny = Employer.new({
      :email => Constants::RECRUITER_EMAIL_FOR_TURK_ADS,
      :first_name => "Jenny",
      :last_name => "Collins",
      :company_name => Constants::SHORT_SITENAME,
      :password => ADMIN_PASSWORD
    })
  emplr_jenny.status = UserConstants::VERIFIED
  emplr_jenny.sample = true
  emplr_jenny.save!  
end

def shutdown_all_jobs
   Job.where("status <> ?", Job::CLOSED).each do |job| 
     job.shutdown!(Interview::CLOSED_EXPIRED) if job.created_at
   end
end

def set_free_plan_for_all_employers
  Employer.all.each do |e|
    plan = e.current_plan
    if plan.nil?
      plan = e.employer_plans.build(:tier => Constants::TIER_BASIC, :monthly_price => 0)
      plan.save!
    end
  end
end


def fix_position_tags_case
  ["Project Manager",
  "Technical Writer",
  "BI Developer",
  "Continuous Integration Engineer",
  "Software Test Developer",
  "Mobile Applications Developer",
  "DevOps Engineer",
  "Lead Dev Ops Engineer",
  "Staff Software Engineer",
  "AutoCAD Developer",
  "Front-End Developer",
  "CTO",
  "Product Manager",
  "Integration Consultant",
  "Information Architect",
  "Business Intelligence Specialist",
  "Data Warehousing Engineer",
  "Reporting Analyst",
  "Dev Lead",
  "Development Manager",
  "Release Engineer",
  "Build Engineer",
  "CIO",
  "Chief Information Officer",
  "Director of Software Development",
  "Chief Technology Officer",
  "Associate Technical Director",
  "Director of Engineering",
  "Technology Manager",
  "Technology Director",
  "DBA",
  "Senior Database Administrator",
  "Field Engineer",
  "Pre-Sales Field Engineer",
  "Hardware Engineer",
  "Android Developer",
  "iOS Developer",
  "Lead Android Developer",
  "Lead iOS Developer",
  "Senior Android Developer",
  "Senior iOS Developer",
  "Mobile App Developer",
  "Senior Product Manager",
  "Software Development Manager",
  "Team Lead",
  "Operations Engineer",
  "DevOps",
  "QA Team Lead",
  "Senior QA Engineer",
  "QA Manager",
  "Researcher",
  "Chief Data Scientist",
  "Research Engineer",
  "Senior Research Scientist",
  "Systems Engineer",
  "Technical Lead",
  "Technical Architect",
  "Technical Evangelist",
  "Performance Architect",
  "Senior System Architect",
  "Principal Software Architect",
  "Solution Architect",
  "Senior Software Architect",
  "Software Consultant",
  "Software Architect",
  "Chief Technologist",
  "Product Architect",
  "Software Design Engineer",
  "System Architect",
  "Senior Java Developer",
  "Kernel Software Engineer",
  "Senior Developer",
  "Principal Software Engineer",
  "Lead PHP Developer",
  "Senior Applications Developer",
  "Senior C# Developer",
  "Senior C++ Developer",
  "Senior UI Developer",
  "Development Engineer",
  "Software Engineer",
  ".NET/C# Developer",
  "Senior Perl Developer",
  "Senior Python Developer",
  "Programmer",
  "Full-Stack Engineer",
  "Applications Developer",
  "C# Developer",
  "C++ Developer",
  "Java Developer",
  "Lead .NET/C# Developer",
  "Lead Application Developer",
  "Lead C# Developer",
  "Lead C++ Developer",
  "Lead Developer",
  "Lead Java Developer",
  "Lead Perl Developer",
  "Lead Python Developer",
  "Lead Software Developer",
  "Lead Software Engineer",
  "Perl Developer",
  "Python Developer",
  "Senior .NET/C# Developer",
  "Senior Software Engineer",
  "Software Developer",
  "Senior Software Developer",
  "Back-End Engineer",
  "Game Developer",
  "System Administrator",
  "Data Scientist",
  "Senior Test Engineer",
  "QA Engineer",
  "Test Engineer",
  "Lead Test Engineer",
  "Software Engineer in Test",
  "UX/UI Engineer",
  "Senior Designer",
  "UX/UI Designer",
  "Lead UX/UI Designer",
  "Designer",
  "UX Architect",
  "UI Developer",
  "Senior UX/UI Designer",
  "Lead UI Developer",
  "UX Designer",
  "Lead Django Developer",
  "Web App Developer",
  "Lead Frontend Developer",
  "Senior Web Developer",
  "Senior RoR Developer",
  "Senior Rails Engineer",
  "Front-End Engineer",
  "Full-Stack Web Developer",
  "Django Developer",
  "Frontend Developer",
  "Joomla Developer",
  "PHP Developer",
  "RoR Developer",
  "Senior JavaScript Developer",
  "Senior Django Developer",
  "Senior Frontend Developer",
  "JavaScript Developer",
  "Lead RoR Developer",
  "Lead Joomla Developer",
  "Lead JavaScript",
  "WordPress Developer",
  "Senior PHP Developer",
  "Senior Joomla Developer",
  "Graphic Designer",
  "Web Developer",
  ".NET Developer",
  "Sysadmin",
  "C++ Software Engineer",
  "C#/.NET Developers",
  "Research and Development Manager",
  "Android Software Engineer",
  "Mobile Development Lead",
  "Associate Software Developer",
  "Android App Developer",
  "Principal Software Developer",
  "Senior Backend Developer",
  "Cloud Developer",
  "Bioinformatics Analyst",
  "Linux Administrator",
  "Sr. Quality Assurance Engineer",
  "Linux System Engineer",
  "QA Automation Engineer",
  "Computer Vision Developer",
  "Junior Software Engineer",
  "Enterprise Software Engineer",
  "Senior Java Software Engineer",
  "VP of Engineering",
  "Data Science Software Engineer",
  "Application Engineer",
  "Android Application Developer",
  ".NET Software Engineer",
  "iOS Application Developer",
  "C# Software Developer",
  "Expert Software Developer",
  "Android Mobile Development Engineer",
  "Senior Ruby Developer",
  "Database Architect",
  "Software Test Engineer",
  "Software Developer in Test",
  "Senior .NET Developer",
  "Ruby on Rails Engineer",
  "Computer Vision Scientist",
  "User Interface Software Engineer",
  "Senior Software Tester",
  "Mobile Developer",
  "Senior Quality Software Engineer",
  "Computer Vision  Engineer",
  "Big Data Analyst",
  "Bioinformatics Developer"].each do |name|
    tag = PositionTag.where("lower(name) = ?", name.downcase).limit(1).first
    if tag.nil?
      puts "Tag not found #{name.downcase}"
    else
      tag.update_attributes(name: name)
    end
  end
end
