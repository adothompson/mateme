class PersonAttribute < ActiveRecord::Base
  set_table_name "person_attribute"
  set_primary_key "person_attribute_id"
  include Openmrs

  belongs_to :type, :class_name => "PersonAttributeType", :foreign_key => :person_attribute_type_id
  belongs_to :person, :foreign_key => :person_id  
end
