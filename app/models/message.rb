class Message < ApplicationRecord
  # Relationships
  belongs_to :chat
  belongs_to :sender, class_name: 'User'
  has_one_attached :attachment

  # Callbacks
  before_create :set_show_sender

  # Validations
  validates :content, presence: true

  # Encryption
  has_encrypted :content

  # Scopes
  scope :all_unread, lambda { |chat, recipient|
                       chat_user = chat.chat_users.mine(recipient)
                       where(created_at: (DateTime.now - 5.minutes)...DateTime.now)
                         .and(Message.where.not(sender: recipient))
                         .and(Message.where('created_at > ?', chat_user.last_seen_at))
                         .order(created_at: :desc)
                     }
  scope :not_mine, ->(user) { where.not(sender: user) }
  scope :oldest, -> { order(created_at: :asc) }
  scope :newest, -> { reorder(created_at: :desc) }

  # Methods
  def content_formatted
    content.gsub("\n", '<br>')
  end

  private

  def set_show_sender
    self.show_sender = if chat.messages.empty?
                         true
                       else
                         !(chat.messages.last.sender_id == sender_id)
                       end
  end
end
