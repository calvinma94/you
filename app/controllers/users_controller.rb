require 'net/sftp'
require 'net/ssh'

class UsersController < ApplicationController
  before_action :logged_in_user, only: [:index, :edit, :update, :files, :destroy]
  before_action :correct_user,   only: [:edit, :update]
  before_action :admin_user,     only: :destroy
  
  def index
    @users = User.paginate(page: params[:page])
  end
  
  def show
    @user = User.find(params[:id])
    session[:user_id] = params[:id]
  end

  def print
    @user = User.find(session[:user_id])
    @filename = sanitize_filename(params[:file])

    Net::SSH.start('fraser.sfu.ca', @user.sfu_computingid, :password => @user.sfu_password, :non_interactive => true, :timeout => 20) do |ssh|
      output = ssh.exec!("hostname")
      puts output

      Net::SSH.start('asb9838n-d10.csil.sfu.ca', @user.sfu_computingid, :password => @user.sfu_password, :non_interactive => true, :timeout => 20, :port => 24) do |ssh|
        output = ssh.exec!("hostname")
        puts output

        ssh.exec "cd sfuhome && touch #{@filename}.copy"
      end
    end
  end

  def download
    @user = User.find(session[:user_id])
    @remotepath = "/ugrad1/" + @user.sfu_computingid + "/" + params[:file]
    @localpath = "#{Rails.root}/public/" + params[:file]

    Net::SFTP.start('fraser.sfu.ca', @user.sfu_computingid, :password => @user.sfu_password, :non_interactive => true, :timeout => 200) do |sftp|
      sftp.download!(@remotepath, @localpath)
    end

    # TODO - check to make sure file downloaded properly

    send_file @localpath, :x_sendfile => true
    @filename = sanitize_filename(params[:file])
    File.delete("#{Rails.root}/public/#{@filename}")
  end

  def sanitize_filename(filename)
    filename.strip.tap do |name|
      name.sub! /\A.*(\\|\/)/, ''
      name.gsub! /[^\w\.\-]/, '_'
    end
  end

  def remove
    @user = User.find(session[:user_id])
    @filename = sanitize_filename(params[:file])
    @remotepath = "/ugrad1/" + @user.sfu_computingid + "/" + @filename
    @localpath = "#{Rails.root}/public/" + params[:file]

    Net::SFTP.start('fraser.sfu.ca', @user.sfu_computingid, :password => @user.sfu_password, :non_interactive => true, :timeout => 200) do |sftp|
      sftp.remove!(@remotepath) 
      redirect_to :action => 'files' and return
    end
  end

  def files
    @user = User.find(session[:user_id])

    if @user.authenticated == nil
      redirect_to :back and return
    end

    @file_list = {}

    if params[:dir].nil?
      @directory = "./"
    else
      @directory = "/ugrad1/" + @user.sfu_computingid + "/" + params[:dir]
    end

    Net::SFTP.start('fraser.sfu.ca', @user.sfu_computingid, :password => @user.sfu_password, :non_interactive => true, :timeout => 200) do |sftp|
      sftp.dir.foreach(@directory) do |entry|
        if entry.directory?
          @file_type = 'directory'
        elsif entry.file?
          @file_type = 'file'
        end

        @file_list[entry.name] = @file_type
      end
    end
  end
  
  def new
    @user = User.new
  end
  
  def destroy
    User.find(params[:id]).destroy
    flash[:success] = "User deleted"
    redirect_to users_url
  end
  
  def create
    @user = User.new(user_params)
    if @user.save
      log_in @user
      flash[:success] = "Welcome to the YouDrive!"
      redirect_to @user
    else
      render 'new'
    end
  end
  
  def edit
    #@user = User.find(params[:id])
  end
  
  def update
    if @user.update_attributes(user_params)
      flash[:success] = "Profile updated"
      redirect_to @user
    else
      render 'edit'
    end
  end

  def auth
    @user = User.find(params[:id])
  end

  def authenticate
    @user = User.find(params[:id])
    if @user.update_attributes(user_params)
      begin
        Net::SFTP.start('fraser.sfu.ca', @user.sfu_computingid, :password => @user.sfu_password, :non_interactive => true, :timeout => 200) do |sftp|
        end

        @user.authenticated = true
        @user.save

      rescue Net::SSH::Exception
        @user.authenticated = false
        flash[:danger] = "Authentication incorrect"
        redirect_to action: "auth" and return
      end
      redirect_to action: "files", id: @user.id
    else
      flash[:danger] = "Unable to authenticate"
      redirect_to action: "auth" and return
    end
  end
  
  private

    def user_params
      params.require(:user).permit(:name, :email, :password,
                                   :password_confirmation, :sfu_computingid, :sfu_password, 
                                   :authenticated)
    end

    # 事前过滤器

    # 确保用户已登录
    def logged_in_user
      unless logged_in?
        store_location
        flash[:danger] = "Please log in."
        redirect_to login_url
      end
    end

    # 确保是正确的用户
    def correct_user
      @user = User.find(params[:id])
      redirect_to(root_url) unless current_user?(@user)
    end
    
    # 确保是管理员
    def admin_user
      redirect_to(root_url) unless current_user.admin?
    end
end
