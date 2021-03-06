class InfointerviewsController < ApplicationController
  before_filter :strip_params, :only => [:create, :close, :reopen, :delegate, :set_seen]
  before_filter :init_employee_user, :except => [:close, :reopen, :serve_avatar, :delegate]
  before_filter :init_infointerview_with_redirect, :only => [:close, :reopen]
  before_filter :init_infointerview, :only => [:set_seen]
  
  # ajax call
  def create
    candidate = nil

    # 1st - check if user provided RightJoin credentials in the widget
    email = params[:email]
    password = params[:password]
    first_name = params[:firstname]
    last_name = params[:lastname]
    
    if !email.blank? && !password.blank?
      candidate = User.find_by_email(email)
      if candidate.nil? || !candidate.authenticate(password)
        render :text => "Invalid email/password combination. Please try again.", status: :unauthorized
        return # invalid credentails, don't even try other options
      end
    end
    
    auth = nil
    resume = nil
    if candidate.nil?
      if !first_name.blank? && !last_name.blank?
        # 2nd - see if user pings with resume
        if params[:document_id].present?
           preloaded = Cloudinary::PreloadedFile.new(params[:document_id])
           resume = preloaded.identifier
        else 
          # 3nd - see if user pings via oauth providers, i.e. provides firstname and lastname
          auth = current_auth(Constants::REMEMBER_TOKEN_INFOINTERVIEW)
        end
      end
      
      if auth.nil? && resume.nil? && signed_in?
        # 4rd - user might happen to be logged in (either direct ping in the widget, or ping button in the board)
        candidate = current_user
      end
    end
    
    employer = Employer.find(params[:employer_id])
    job = employer.jobs.find(params[:job_id])
    
    if auth.nil? && candidate.nil? && resume.nil?
      render :nothing => true, status: :unauthorized
    elsif !candidate.nil? && candidate.status == UserConstants::PENDING
      render :text => "Please verify your #{Constants::SHORT_SITENAME} account and retry.", status: :unauthorized
    elsif !candidate.nil? && (candidate.first_name.blank? || candidate.last_name.blank?)
      render :text => "Ping failed. Your #{Constants::SHORT_SITENAME} account is incomplete. Please fill out and retry.", status: :unauthorized
    elsif job.status != Job::PUBLISHED
      # silently ignore pings to closed or not published ads
      # is this correct behavior?
      # it's fine for drafts, but might be problematic for closed jobs
      render :nothing => true, status: :ok
    else
      infointerview = Infointerview.new
      infointerview.job_id = job.id  
      
      infointerview.email = email
      infointerview.first_name = first_name
      infointerview.last_name = last_name
      
      unless auth.nil?
        infointerview.auth = auth
        infointerview.profiles = auth.profiles_to_str
      end
      
      if candidate.nil?
        infointerview.update_candidate_after_ping = true
      else
        infointerview.user_id = candidate.id
        infointerview.profiles ||= candidate.resume
        infointerview.email ||= candidate.email
        infointerview.first_name ||= candidate.first_name
        infointerview.last_name ||= candidate.last_name
      end
      
      unless resume.nil?
        infointerview.resume_doc_id = resume
      end
      
      older_infointerviews = Infointerview.find_by_job_id_and_email(infointerview.job_id, infointerview.email)
      
      if older_infointerviews.nil? # silently ignore repeating pings from the same user to the same job
        infointerview.save!
        
        begin
          Reminder.create_event!(infointerview.id, Reminder::NEW_LEAD)
          lead_attrs = {:network => @sliding_session.channel, :job_id => job.id, :ambassador_id => nil, :ip => @sliding_session.ip, :referer => @sliding_session.referer, :lead_counter => 1}
          
          referred_by = Ambassador.find_by_id(@sliding_session.referred_by)
          if referred_by && employer.id == referred_by.employer_id # not necessarily the same job, but must be the same employer
            infointerview.referred_by = referred_by.id
            infointerview.save!
            
            lead_attrs[:ambassador_id] = referred_by.id
            Comment.create_system_comment!(infointerview.id, "#{infointerview.first_name} was referred by #{referred_by.first_name} #{referred_by.last_name} via #{Share::DISTRIBUTION_CHANNEL_INFO[@sliding_session.channel][:display_name]}.") 
          end
          
          Share.create!(lead_attrs)
          
          # generate system comments
          was_pinged_by_company = false
          unless candidate.nil?
            # did company pinged this candidate?
            interview = Interview.find_by_user_id_and_job_id(candidate.id, job.id)
            if !interview.nil? && interview.status != Interview::RECOMMENDED
              was_pinged_by_company = true
            end
          end
          
          if was_pinged_by_company
            Comment.create_system_comment!(infointerview.id, "#{infointerview.first_name} was pinged by #{employer.company_name} regarding the #{job.position_name} position.", interview.created_at)
            Comment.create_system_comment!(infointerview.id, "#{infointerview.first_name} pinged you back.")
          else
            Comment.create_system_comment!(infointerview.id, "#{infointerview.first_name} pinged #{employer.company_name} regarding the #{job.position_name} position.")
          end
          
        rescue Exception => e # report and ignore
          logger.error e
        end
      end

      render :nothing => true, status: :ok
    end
  rescue ActiveRecord::RecordInvalid # likely because of the missing fileds in the user profile
    render :nothing => true, status: :internal_server_error
  rescue Exception => e 
    logger.error e
    render :nothing => true, status: :forbidden
  end
  
  def close
    @infointerview.status = Infointerview::CLOSED_BY_EMPLOYER
    @infointerview.save!
    
    Comment.create_system_comment!(@infointerview.id, "The lead was closed.")
    
    @infointerview.followups.only_active.update_all(:status => Followup::CLOSED)
    
    flash_message(:notice, "You have closed a lead.")
    
    redirect_to leads_employer_job_path(current_user, @infointerview.job, :locale => @infointerview.job.country_code)
  rescue Exception => e
    logger.error e
    flash_message(:error, Constants::ERROR_FLASH)
    redirect_to employer_path(current_user)
  end
  
  def serve_avatar
    ref_num = params[:refnum]
    infointerview = Infointerview.find_by_ref_num(ref_num)
    raise "Lead wasn't found or is invalid" if infointerview.nil?
    
    auth = infointerview.auth
    if !auth.nil? && !auth.avatar.blank? && !auth.avatar_content_type.blank?
      response.headers['Cache-Control'] = 'public, max-age=300' unless params[:timestamp].blank?
      send_data(auth.avatar, :type => auth.avatar_content_type, :filename => "#{infointerview.id}", :disposition => "inline")
    else
      send_file "#{Rails.root}/public/no-avatar.png", :type => "image/png", :disposition => "inline"
    end
    
  rescue Exception => e
    logger.error e
    send_file "#{Rails.root}/public/no-avatar.png", :type => "image/png", :disposition => "inline"
    
  end
  
  def reopen
    @infointerview.status = Infointerview::ACTIVE_SEEN_BY_EMPLOYER
    @infointerview.save!
    
    Comment.create_system_comment!(@infointerview.id, "The lead was reopened.")
    
    flash_message(:notice, "You have reopened the lead.")
    
    redirect_to leads_employer_job_path(current_user, @infointerview.job, :locale => @infointerview.job.country_code)
  rescue Exception => e
    logger.error e
    flash_message(:error, Constants::ERROR_FLASH)
    redirect_to employer_path(current_user)
  end  
  
  def delegate
    init_infointerview
    ambassador = Ambassador.find(params[:ambassador_id])
    
    # don't create a Followup object if already delegated and still NEW
    followup = ambassador.followups.only_active.find_by_infointerview_id(@infointerview.id)
    if followup.nil?
      followup = ambassador.followups.build(:infointerview => @infointerview) 
      followup.save!
    end
    
    Comment.create_system_comment!(@infointerview.id, "Delegated to #{ambassador.first_name} #{ambassador.last_name}.")
    
    msg = FyiMailer.create_delegate_infointerview_email(followup)
    Utils.deliver msg
    
    render :partial => "comments/lead_comments", :locals => { :lead => @infointerview, :display_for => ambassador }, :layout => false
    
  rescue Exception => e
    render :nothing => true, status: :forbidden
  end  
  
  # seen by employer
  def set_seen
    @infointerview.status = Infointerview::ACTIVE_SEEN_BY_EMPLOYER
    @infointerview.save!
    
    render :nothing => true, status: :ok
    
  rescue  Exception => e
    logger.error e
    render :nothing => true, status: :forbidden
  end    
  
private
  def init_infointerview_with_redirect
    init_infointerview
 
  rescue Exception => e
    logger.error e
    flash_message(:error, Constants::NOT_AUTHORIZED_FLASH)
    if signed_in?
      redirect_to employer_path(current_user)
    else
      redirect_to employer_welcome_path
    end    
  end
  
  def init_infointerview
    @infointerview = Infointerview.find params[:id]
    
    init_employer_user
    
    raise "Employer must be signed in" unless signed_in?
    raise "Employer mismatch" unless @infointerview.job.employer_id == current_user.id    
  end
end
