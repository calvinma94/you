require 'net/sftp'

class UploadsController < ApplicationController

  def new
    @upload = Upload.new
  end

  def create
    @upload = Upload.new(upload_params)
    @user = User.find(session[:user_id])
    @remotepath = "/ugrad1/" + @user.sfu_computingid + "/" + @upload.file_file_name

    if @upload.save
      Net::SFTP.start('fraser.sfu.ca', @user.sfu_computingid, :password => @user.sfu_password, :non_interactive => true, :timeout => 200) do |sftp|
        sftp.upload!(@upload.file.path, @remotepath)
      end

      @upload.destroy
      flash[:success] = "File uploaded!"
      render json: { message: "uploadok" },:status => 200
      #redirect_to :controller => 'files', :action => 'list'
    else
      render 'new'
    end
  end

  private

  def upload_params
    params.require(:upload).permit(:file)
  end

end
