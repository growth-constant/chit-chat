class Chat::Turbo::PreviewsService
  def self.update_chat_previews(chat, sender, receiver)
    contacts = [[sender, receiver], [receiver, sender]]
    turbo_frames = %i[preview_mobile preview]
    # we used to replace all frames because all were loaded at the same time
    # now only five and these might not contain the chat we are looking for
    # so we need to delete the previews and prepend them again and someone keep on the
    # frontend the id of the selected chat
    turbo_frames.each do |turbo_frame|
      turbo_frame = ActionView::RecordIdentifier.dom_id(chat, turbo_frame)
      contacts.each do |me, other|
        chat.broadcast_replace_later_to(
          me, :chats,
          target: turbo_frame,
          partial: 'chats/chat/preview_content',
          locals: { chat:, other:, me:, turbo_frame: }
        )
      end
    end
  end

  def self.prepend_chat_preview(chat, sender, receiver)
    contacts = [[sender, receiver], [receiver, sender]]
    contacts.each do |me, other|
      chat.broadcast_prepend_later_to(
        me, :chats,
        target: :chats,
        partial: 'chats/chat/preview',
        locals: { chat:, other:, me: }
      )
    end
  end
end
