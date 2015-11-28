class GoogleController < ApplicationController

require 'google/apis/drive_v2'
require 'google/api_client/client_secrets'
require 'json'
require 'addressable/uri'
Drive = Google::Apis::DriveV2 # Alias the module
  def main
    drive= get_client
    unless drive
     redirect_to google_oauth2callback_path and return
    end
    begin
      @files = drive.list_files(corpus:'DOMAIN', q:'trashed=false') #gets directory
      @aboutme= drive.get_about()
    rescue Google::Apis::AuthorizationError
      session.delete(:credentials)
      params.delete(:code)
      redirect_to google_oauth2callback_path and return
    end
  end  

  def upload
    drive=get_client
    unless drive
    redirect_to google_oauth2callback_path and return
    end
    begin
      @aboutme=drive.get_about()
      drive.insert_file({title: params[:file].original_filename}, upload_source: params[:file].path ,content_type: params[:file].content_type)  
      render 'uploadok'
    rescue Google::Apis::AuthorizationError
      session.delete(:credentials)
      params.delete(:code)
      redirect_to google_oauth2callback_path and return
    end
  end
  
  def uploadform
    drive=get_client
    unless drive
      redirect_to google_oauth2callback_path and return
    end
    begin
      @aboutme= drive.get_about()
    rescue Google::Apis::AuthorizationError
      session.delete(:credentials)
      params.delete(:code)
      redirect_to google_oauth2callback_path and return
    end
  end
  
  def get_client
    if session[:credentials]
      begin
          client_opts = JSON.parse(session[:credentials])
          authuri=Addressable::URI.new(client_opts['authorization_uri'])
          tokuri=Addressable::URI.new(client_opts['token_credential_uri'])
          auth_client = Signet::OAuth2::Client.new(
               :authorization_uri =>
                 authuri,
               :token_credential_uri =>
                 tokuri,
               :client_id => client_opts['client_id'],
               :client_secret => client_opts['client_secret'],
               :scope => client_opts['scope'],
               :redirect_uri => 'https://cmpt276a1-calmel05.c9.io/google/oauth2callback'
               )
          auth_client.grant_type= 'authorization_code'
          auth_client.update!(
          :access_token => client_opts['access_token'],
          :id_token => client_opts['id_token'])
          #Google::Apis::RequestOptions.default.authorization = auth_client
          drive = Drive::DriveService.new
          drive.authorization = auth_client # See Googleauth or Signet libraries
          puts 'returning drive'
          return drive
      rescue
          # Maybe something's wrong with the access token?
          session.delete(:credentials)
          raise
      end
    end
  end




  def oauth2callback
  client_secrets = Google::APIClient::ClientSecrets.load('client_secret.json')
  auth_client = client_secrets.to_authorization
  auth_client.update!(
    :scope => 'https://www.googleapis.com/auth/drive',
    :redirect_uri =>  (url_for :controller => 'google', :action => 'oauth2callback'),
    )
  
  auth_client.grant_type= 'authorization_code'
  unless params[:code]
    auth_uri = auth_client.authorization_uri.to_s
    redirect_to auth_uri and return
  end
  puts params[:code]
    auth_client.code = params[:code]
    auth_client.fetch_access_token!
    auth_client.client_secret = nil
    credentials=auth_client.to_json
    session[:credentials] = credentials
    redirect_to(:action => 'main') and return
  end
  
  
  
  def logout
    session.delete(:credentials)
    redirect_to root_path and return
  end

end