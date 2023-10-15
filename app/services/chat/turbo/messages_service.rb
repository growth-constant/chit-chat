class Chat::Turbo::MessagesService
  def self.send_chat_message_update_to_users(chat, user, message, broadcast_all: true)
    chat.touch(time: message.created_at)

    receiver = chat.first_other_users(user)
    # send the receiver of the message a boardcast of message
    Chat::PreviewsService.update_chat_previews(chat, user, receiver)
    # update the last seen time of the sender
    Chat::MessagesService.set_read_up_to_message(chat, message, user)
    # send the users the updates of the chat
    Chat::MessagesService.broadcast_chat_message(chat, user, message, is_read: true) if broadcast_all
    Chat::MessagesService.broadcast_chat_message(chat, receiver, message, is_read: false)
  end

  def self.broadcast_chat_message(chat, receiver, message, is_read: false)
    message.broadcast_append_later_to chat, receiver, :messages, target: 'messages',
                                                                 locals: { is_read:, scroll_bottom: true }
  end

  def self.set_read_messages_for(chat, user)
    newest_messages = chat.messages.newest
    update_read = newest_messages.any? ? newest_messages.first.created_at : nil
    return if update_read.nil?

    chat_user = chat.chat_users.mine(user)
    chat_user.update!(last_seen_at: update_read) if update_read > chat_user.last_seen_at
  end

  def self.set_read_up_to_message(chat, message, user)
    update_read = message.created_at

    chat_user = chat.chat_users.mine(user)
    chat_user.update!(last_seen_at: update_read) if update_read > chat_user.last_seen_at
  end

  def self.notify_latest_unread_messages
    ChatUser.latest_updated.each do |chat_user|
      user = chat_user.user
      chat = chat_user.chat
      # get unseen messages
      sender = chat.first_other_users(user)
      NewMessageNotification.with(chat:, sender:).deliver_later(user)
    end
  end
end
