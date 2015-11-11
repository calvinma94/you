require 'net/sftp'

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

  def files
    @user = User.find(session[:user_id])
    @file_list = {}

    if params[:dir].nil?
      @directory = "./"
    else
      @directory = params[:dir]
    end

    begin
      Net::SFTP.start('fraser.sfu.ca', @user.sfu_computingid, :password => @user.sfu_password, :non_interactive => true, :timeout => 10) do |sftp|
        sftp.dir.foreach(@directory) do |entry|
          if entry.directory?
            @file_type = 'directory'
          elsif entry.file?
            @file_type = 'file'
          end

          @file_list[entry.name] = @file_type
        end
      end

      @user.authenticated = true
      @user.save

    rescue Net::SSH::Exception
      @user.authenticated = false
      redirect_to action: "auth", id: @user.id
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
