class ChatsController < ApplicationController
  before_action :allow_only_signed_in_users
  breadcrumb 'Messages', :chats_path
  include ::Pagy::Backend

  # GET /chats
  def index
    @chats = Chat.dms_for(current_user)

    # get the selected chat from the list of chats and
    # show it first in the index view, if it exists
    @chats, @selected_chat = add_selected_chat(@chats)
    
    # get the chats with users paginated 
    @chats_pagy, @chats = pagy_countless(@chats, items: 5)

    return if @selected_chat.blank? && @chats.empty?

    @chat = (@selected_chat.presence || @chats.first)
    Chat::MessagesService.set_read_messages_for @chat, current_user if @chat.present?
    @reciver = @chat.first_other_users(current_user)
    @pagy, @messages = pagy_countless(@chat.messages.newest, items: 10)
  end
  
  # GET /chats/:id
  def show
    @chat = Chat.find(params[:id])
    Chat::MessagesService.set_read_messages_for @chat, current_user
    @reciver = @chat.first_other_users(current_user)
    @pagy, @messages = pagy_countless(@chat.messages.newest, items: 10)
  end
  
  # GET /chats/:id/chats?page=...
  def chats
    respond_to :turbo_stream
    @pagy, @chats = chats_search
  end
  
  # GET /chats/search?name=...
  def search
    respond_to :turbo_stream
    @pagy, @chats = chats_search
  end
  
  # GET /chats/:id/messages?page=...
  def messages
    respond_to :turbo_stream
    @pagy, @messages = pagy_countless(Chat.find(params[:id]).messages.newest, items: 10)
  end
  
  # GET /chats/:id/display
  def display
    @chat = Chat.find(params[:id])
    Chat::MessagesService.set_read_messages_for @chat, current_user
    @reciver = @chat.first_other_users(current_user)
    @pagy, @messages = pagy_countless(@chat.messages.newest, items: 10)
    render :display
  end
  
  # PATCH /chats/:id/last_read
  def last_read
    @message = Message.where(chat_id: params[:id], id: params[:last_message_id]).first
    @chat = @message.chat
    Chat::MessagesService.set_read_up_to_message @chat, @message, current_user if @message.present?
    render json: {}
  end
  
  # GET /chats/new?user_id=:user_id
  def new
    reciver = User.find(params[:user_id])
    chat = Chat.between(current_user, reciver)
    
    return redirect_to chats_path, alert: 'You can not send message to yourself' if current_user.id == reciver.id

    if chat.present?
      respond_to do |format|
        format.html { redirect_to chats_path(selected: chat) }
      end
    else
      name = params[:name]
      chat = Chat.create(name:)
      chat.users << current_user
      chat.users << reciver
      
      respond_to :html
      Chat::PreviewsService.prepend_chat_preview(chat, current_user, reciver)
      redirect_to chats_path(selected: chat.id)
    end
  end
  
  private
  
  def chats_search
    if params[:q].blank?
      chats_wout_search
    else
      chats_with_search
    end
  end

  def add_selected_chat(chats)
    selected_id = params[:selected]
    if selected_id.present?
      selected_chat = chats.where(id: selected_id).with_users.first
      chats = chats.where.not(id: selected_id).with_users
      [chats, selected_chat]
    else
      [chats, nil]
    end
  end
  
  def chats_wout_search
    @q = nil
    chats = Chat.dms_for(current_user)
    # remove the selected chat from the list of chats
    chats, selected_chat = add_selected_chat(chats)
    pagy_countless(chats, items: 5)
  end
  
  def chats_with_search
    @q = search_params
    pagy_countless(
      Chat.dms_for(current_user)
          .joins(:users).where.not(users: { id: current_user.id })
          .ransack(search_params).result,
      items: 5
    )
  end

  def search_params
    (params[:q] || {}).permit(:users_first_name_or_users_last_name_start)
  end
end
