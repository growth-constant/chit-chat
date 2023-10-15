class Webhooks::MailgunController < ActionMailbox::Ingresses::Mailgun::InboundEmailsController
  # we used the mailgun mailbox ingress controller since much of the
  # functionality is already built in

  skip_before_action :ensure_configured
  # message is authenticated by Mailgun ingress in actionmailbox library

  before_action :authenticate
  before_action :get_stripped_text_body

  def webhook
    # if 200 is returned, mailgun will determine post was successful
    # if 406 is returned, mailgun will not retry the request
    to = Mail::Address.new(params['recipient'] || '').address
    reply_to_domain = Rails.configuration.reply_to_domain
    @chat = Chat.find_by_email_chat_reply_id(email: to, reply_domain: reply_to_domain)
    return head :not_acceptable if @chat.blank?

    Rails.logger.info "Chat found: #{@chat.id}"

    # check if user is in db
    from = Mail::Address.new(params['sender'] || '').address
    @user = @chat.users.find_by(email: from)
    return head :not_acceptable if @user.blank?

    Rails.logger.info "User found to belong to chat: #{@user.id}"

    # creat a new message for the user
    @message = @chat.messages.create!(sender: @user, content: @body)
    Chat::MessagesService.send_chat_message_update_to_users(@chat, @user, @message, broadcast_all: true)
    head :ok
  end

  private

  def authenticate
    unless authenticated?
      Rails.logger.info "Unable to authenticate request from #{request.remote_ip}"
      head :unauthorized
    end
  end

  def get_stripped_text_body
    @body = nil
    text = params['stripped-text']
    return @body = text if text.present?

    text = params['body-plain']
    @body = parse_text_part(text) if text.present?

    return if @body.present?

    head :not_acceptable
  end

  def parse_text_part(body)
    capture = /^(?<body>.+)On.*Build It - Update/m.match(body)
    return capture[:body].strip if capture.present?

    # spanish reply emails
    capture = /^(?<body>.+)El.*Build It - Update/im.match(body)
    return capture[:body].strip if capture.present?

    # all other emails
    capture = /^(?<body>.+).*Build It - Update/im.match(body)
    return capture[:body].strip if capture.present?

    # others
    nil
  end
end
