class ProgramOrdersMap < ActiveRecord::Base
  set_table_name "program_orders_map"
  set_primary_key "program_orders_map_id"
  include Openmrs
  belongs_to :program
  belongs_to :concept
end
