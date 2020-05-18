# frozen_string_literal: true

class Users::RegistrationsController < Devise::RegistrationsController
  # before_action :configure_sign_up_params, only: [:create]
  # before_action :configure_account_update_params, only: [:update]
  prepend_before_action :check_recaptcha, only: [:create]
  before_action :session_has_not_user, only: [:confirm_phone, :new_address, :create_address]
  layout 'no_menu'

  # GET /resource/sign_up
  def new
    if session["devise.sns_auth"]
      ## session["devise.sns_auth"]がある＝sns認証
      build_resource(session["devise.sns_auth"][:user])
      @sns_auth = true
    else
      ## session["devise.sns_auth"]がない=sns認証ではない
      super
    end
  end

  # POST /resource
  def create

    if session["devise.sns_auth"]
      ## SNS認証でユーザー登録をしようとしている場合
      ## パスワードが未入力なのでランダムで生成する
      password = Devise.friendly_token[8,12]+ "1a"
      ## 生成したパスワードをparamsに入れる
      params[:user][:password] = password
      params[:user][:password_confirmation] = password
    end

    build_resource(sign_up_params)  ## @user = User.new(user_params) をしているイメージ

    unless resource.valid? ## 登録に失敗したとき
      ## 進捗バー用の@progressとflashメッセージをセットして戻る
      @progress = 1
      @sns_auth = true if session["devise.sns_auth"]
      flash.now[:alert] = resource.errors.full_messages
      render :new and return
    end

    session["devise.user_object"] = @user  ## sessionに@userを入れる
    respond_with resource, location: after_sign_up_path_for(resource)  ## リダイレクト
    ## ↓resource（@user）にsns_credentialを紐付けている
    resource.build_sns_credential(session["devise.sns_auth"]["sns_credential"]) if session["devise.sns_auth"]

    if resource.save  ## @user.save をしているイメージ
      set_flash_message! :notice, :signed_up  ## フラッシュメッセージのセット
      sign_up(resource_name, resource)  ## 新規登録＆ログイン
      respond_with resource, location: after_sign_up_path_for(resource)  ## リダイレクト
    else
      redirect_to new_user_registration_path, alert: @user.errors.full_messages
    end

  end

  # GET /resource/edit
  # def edit
  #   super
  # end

  # PUT /resource
  # def update
  #   super
  # end

  # DELETE /resource
  # def destroy
  #   super
  # end

  # GET /resource/cancel
  # Forces the session data which is usually expired after sign
  # in to be expired now. This is useful if the user wants to
  # cancel oauth signing in/up in the middle of the process,
  # removing all OAuth session data.
  # def cancel
  #   super
  # end

  def select
    session.delete("devise.sns_auth")## 追加
    @auth_text = "で登録する"
  end

  def confirm_phone
    @progress = 2
  end

  def new_address
    @progress = 3
    @address = Address.new
  end

  def create_address
    @progress = 5
    @address = Address.new(address_params)
    if @address.invalid? ## バリデーションに引っかかる（save不可な）時
      redirect_to users_new_address_path, alert: @address.errors.full_messages
    end
  end

  def session_has_not_user
    redirect_to new_user_registration_path, alert: "会員情報を入力してください。" unless session["devise.user_object"].present?
  end

  # protected

  # If you have extra params to permit, append them to the sanitizer.
  # def configure_sign_up_params
  #   devise_parameter_sanitizer.permit(:sign_up, keys: [:attribute])
  # end

  # If you have extra params to permit, append them to the sanitizer.
  # def configure_account_update_params
  #   devise_parameter_sanitizer.permit(:account_update, keys: [:attribute])
  # end

  # The path used after sign up.
  # def after_sign_up_path_for(resource)
  #   super(resource)
  # end

  # The path used after sign up for inactive accounts.
  # def after_inactive_sign_up_path_for(resource)
  #   super(resource)
  # end


  private
  
    def after_sign_up_path_for(resource)
      users_confirm_phone_path
    end

    def check_recaptcha
      redirect_to new_user_registration_path unless verify_recaptcha(message: "reCAPTCHAを承認してください")
    end

    def address_params
      params.require(:address).permit(
        :phone_number,
        :postal_code,
        :prefecture_id,
        :city,
        :house_number,
        :building_name,
    end

end
