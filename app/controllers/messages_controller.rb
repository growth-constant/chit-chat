class MessagesController < ApplicationController
  include ActionView::RecordIdentifier
  before_action :allow_only_signed_in_users
  before_action :set_chat

  # POST /chats/:id/messages
  def create
    @message = @chat.messages.create!(sender: current_user, content: message_params[:content])
    # send the users of chat the updates of the chat
    Chat::MessagesService.send_chat_message_update_to_users(@chat, current_user, @message, broadcast_all: false)
    respond_to :turbo_stream
  end

  private

  def message_params
    params.require(:message).permit(:content)
  end

  def set_chat
    @chat = Chat.find(params[:chat_id])
  end

  def set_show_sender
    if @chat.messages.empty?
      true
    else
      !(@chat.messages.last.sender == current_user)
    end
  end
end
