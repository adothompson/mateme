class ProgramPatientIdentifierTypeMap < ActiveRecord::Base
  set_table_name "program_patient_identifier_type_map"
  set_primary_key "program_patient_identifier_type_map_id"
  include Openmrs
  belongs_to :program
  belongs_to :patient_identifier_type
end
