require 'sequel/extensions/pg_array'

class User
  include Hanami::Entity
  attributes :name, :age, :created_at, :updated_at
end

class Article
  include Hanami::Entity
  include Hanami::Entity::DirtyTracking
  attributes :user_id, :unmapped_attribute, :title, :comments_count, :tags
end

class Repository
  include Hanami::Entity
  attributes :id, :name
end

class CustomUserRepository
  include Hanami::Repository
end

class UserRepository
  include Hanami::Repository
end

class SubclassedUserRepository < UserRepository
end

class UnmappedRepository
  include Hanami::Repository
end

class ArticleRepository
  include Hanami::Repository

  def rank
    query do
      desc(:comments_count)
    end
  end

  def by_user(user)
    query do
      where(user_id: user.id)
    end
  end

  def not_by_user(user)
    exclude by_user(user)
  end

  def rank_by_user(user)
    rank.by_user(user)
  end

  def reset_comments_count
    execute("UPDATE articles SET comments_count = '0'")
  end

  def find_raw
    fetch("SELECT * FROM articles")
  end

  def each_titles
    result = []

    fetch("SELECT s_title FROM articles") do |article|
      result << article[:s_title]
    end

    result
  end

  def map_titles
    fetch("SELECT s_title FROM articles").map do |article|
      article[:s_title]
    end
  end
end

class Robot
  include Hanami::Entity
  attributes :name, :build_date
end

class RobotRepository
  include Hanami::Repository
end

[SQLITE_CONNECTION_STRING, POSTGRES_CONNECTION_STRING].each do |conn_string|
  require 'hanami/utils/io'

  Hanami::Utils::IO.silence_warnings do
    DB = Sequel.connect(conn_string)
  end

  DB.create_table :users do
    primary_key :id
    Integer :country_id, unique: true
    String  :name
    Integer :age
    DateTime :created_at
    DateTime :updated_at
  end

  DB.create_table :articles do
    primary_key :_id
    Integer :user_id
    String  :s_title
    String  :comments_count # Not an error: we're testing String => Integer coercion
    String  :umapped_column

    if conn_string.match(/postgres/)
      column :tags, 'text[]'
    else
      column :tags, String
    end
  end

  DB.create_table :devices do
    primary_key :id
    Integer     :u_id # user_id: legacy schema simulation
  end

  DB.create_table :orders do
    primary_key :id
    Integer :user_id
    Integer :total
  end

  DB.create_table :ages do
    primary_key :id
    Integer :value
    String  :label
  end

  DB.create_table :countries do
    primary_key :country_id
    String :code
  end

  if conn_string.match(/postgres/)
    DB.run('CREATE EXTENSION IF NOT EXISTS "uuid-ossp"')
    DB.create_table :robots do
      column :id, :uuid, :default => Sequel.function(:uuid_generate_v1mc), primary_key: true
      String :name
      DateTime :build_date
    end
  end
end

class PGArray < Hanami::Model::Coercer
  def self.dump(value)
    ::Sequel.pg_array(value) rescue nil
  end

  def self.load(value)
    ::Kernel.Array(value) unless value.nil?
  end
end

#FIXME this should be passed by the framework internals.
MAPPER = Hanami::Model::Mapper.new do
  collection :users do
    entity User

    attribute :id,         Integer
    attribute :name,       String
    attribute :age,        Integer
    attribute :created_at, DateTime
    attribute :updated_at, DateTime
  end

  collection :articles do
    entity Article

    attribute :id,             Integer, as: :_id
    attribute :user_id,        Integer
    attribute :title,          String,  as: 's_title'
    attribute :comments_count, Integer
    attribute :tags,           PGArray

    identity :_id
  end

  collection :robots do
    entity Robot

    attribute :id, String
    attribute :name, String
    attribute :build_date, DateTime
  end
end

MAPPER.load!
