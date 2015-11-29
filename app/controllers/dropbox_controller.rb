#include DropboxHelper
  
require 'dropbox_sdk'
require 'securerandom'

APP_KEY = 'zun0mrf9rzhthgl'
APP_SECRET = 'rcfrfr3q6k8zppt'
class DropboxController < ApplicationController

    def main
        client = get_dropbox_client
        unless client
            redirect_to(:action => 'auth_start') and return
        end
        begin
        @account_info = client.account_info #object that holds account info
        rescue DropboxAuthError => e
          session.delete(:access_token)  # An auth error means the access token is probably bad
          logger.info "Dropbox auth error: #{e}"
          render "autherror"
        rescue DropboxError => e
          logger.info "Dropbox API error: #{e}"
          render 'dropboxerror'
        end

        # Show a file upload page
        render 'main'
    end
    
    def listfiles
        client = get_dropbox_client
        unless client
            redirect_to(:action => 'auth_start') and return
        end
        # Call DropboxClient.metadata
        path = params[:path] || '/'
        begin
        @entry = client.metadata(path)
        @account_info = client.account_info
        rescue DropboxAuthError => e
          session.delete(:access_token)  # An auth error means the access token is probably bad
          logger.info "Dropbox auth error: #{e}"
          render "autherror"
        rescue DropboxError => e
          logger.info "Dropbox API error: #{e}"
          render 'dropboxerror'
        end
    end
    
    def download
        path=params[:path]
        unless path
            redirect_to(:action => 'listfiles')  and return
        end
        client = get_dropbox_client
        unless client
            redirect_to(:action => 'auth_start') and return
        end
        puts 'before begin'
        begin
            puts 'after begin'
            url=client.media(path)
            output=url['url']
            redirect_to output
        rescue DropboxAuthError => e
          session.delete(:access_token)  # An auth error means the access token is probably bad
          logger.info "Dropbox auth error: #{e}"
          render "autherror"
          #render :text => "Dropbox auth error"
        rescue DropboxError => e
          logger.info "Dropbox API error: #{e}"
          #render :text => "Dropbox API error"
          render 'dropboxerror'
        end
    end    
        
        
    def upload
        client = get_dropbox_client
        unless client
            redirect_to(:action => 'auth_start') and return
        end
        @account_info = client.account_info
        begin
            # Upload the POST'd file to Dropbox, keeping the same name
            @resp = client.put_file(params[:file].original_filename, params[:file].read)
            render json: { message: "success" }, :status => 200
        rescue DropboxAuthError => e
            session.delete(:access_token)  # An auth error means the access token is probably bad
            logger.info "Dropbox auth error: #{e}"
            render json: { message: "autherror" }, :status => 400
        rescue DropboxError => e
            logger.info "Dropbox API error: #{e}"
            render json: { message: "dropboxerror" }, :status => 400
        end
    end

    def get_dropbox_client
        if session[:access_token]
            begin
                access_token = session[:access_token]
                DropboxClient.new(access_token)
            rescue
                # Maybe something's wrong with the access token?
                session.delete(:access_token)
                raise
            end
        end
    end

    def get_web_auth()
        redirect_uri = url_for(:action => 'auth_finish')
        DropboxOAuth2Flow.new(APP_KEY, APP_SECRET, redirect_uri, session, :dropbox_auth_csrf_token)
    end

    def auth_start
        authorize_url = get_web_auth().start()

        # Send the user to the Dropbox website so they can authorize our app.  After the user
        # authorizes our app, Dropbox will redirect them here with a 'code' parameter.
        redirect_to authorize_url
    end

    def auth_finish
    begin
      access_token, user_id, url_state = get_web_auth.finish(params)
      session[:access_token] = access_token
      redirect_to :action => 'listfiles'
    rescue DropboxOAuth2Flow::BadRequestError => e
      render :text => "Error in OAuth 2 flow: Bad request: #{e}"
    rescue DropboxOAuth2Flow::BadStateError => e
      logger.info("Error in OAuth 2 flow: No CSRF token in session: #{e}")
      redirect_to(:action => 'auth_start')
    rescue DropboxOAuth2Flow::CsrfError => e
      logger.info("Error in OAuth 2 flow: CSRF mismatch: #{e}")
      render :text => "CSRF error"
    rescue DropboxOAuth2Flow::NotApprovedError => e
      #render :text => "Not approved?  Why not, bro?"
      render 'dropboxerror'
    rescue DropboxOAuth2Flow::ProviderError => e
      logger.info "Error in OAuth 2 flow: Error redirect from Dropbox: #{e}"
      render :text => "Strange error."
    rescue DropboxError => e
      logger.info "Error getting OAuth 2 access token: #{e}"
      render :text => "Error communicating with Dropbox servers."
    end
    end
    
    def dropsession
        client = get_dropbox_client
        if client
            client.disable_access_token
        end
        session.delete(:access_token)
        redirect_to root_path and return
    end
end
