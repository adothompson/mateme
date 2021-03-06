require 'digest/sha1'
require 'digest/sha2'

class User < ActiveRecord::Base
  include Openmrs
  set_table_name :users
  set_primary_key :user_id
  before_create :set_password

  cattr_accessor :current_user
  attr_accessor :plain_password

  has_many :user_properties, :foreign_key => :user_id
  has_many :user_roles, :foreign_key => :user_id, :dependent => :delete_all

  def name
    self.first_name + " " + self.last_name
  end
  
  def set_password
    # We expect that the default OpenMRS interface is used to create users
    self.password = encrypt(self.plain_password, self.salt) if self.plain_password
  end
   
  def self.authenticate(login, password)
    u = find :first, :conditions => {:username => login} 
    u && u.authenticated?(password) ? u : nil
  end
      
  def authenticated?(plain)
    encrypt(plain, salt) == password || Digest::SHA1.hexdigest("#{plain}#{salt}") == password || Digest::SHA512.hexdigest("#{plain}#{salt}") == password
  end
  
  def admin?
    user_roles.map{|user_role| user_role.role }.include? 'Informatics Manager'
  end  
      
  # Encrypts plain data with the salt.
  # Digest::SHA1.hexdigest("#{plain}#{salt}") would be equivalent to
  # MySQL SHA1 method, however OpenMRS uses a custom hex encoding which drops
  # Leading zeroes
  def encrypt(plain, salt)
    encoding = ""
    digest = Digest::SHA1.digest("#{plain}#{salt}") 
    (0..digest.size-1).each{|i| encoding << digest[i].to_s(16) }
    encoding
  end  
end
