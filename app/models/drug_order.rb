class DrugOrder < ActiveRecord::Base
  include Openmrs
  set_table_name :drug_order
  set_primary_key :order_id
  belongs_to :drug, :foreign_key => :drug_inventory_id

  def order
    @order ||= Order.find(order_id)
  end
  
  def to_s 
    return order.instructions unless order.instructions.blank? rescue nil
    s = "#{drug.name}: #{self.dose} #{self.units} #{frequency} for #{duration} days"
    s << " (prn)" if prn == 1
    s
  end
  
  def to_short_s
    return order.instructions unless order.instructions.blank? rescue nil
    s = "#{drug.name}: #{self.dose} #{self.units} #{frequency} for #{duration} days"
    s << " (prn)" if prn == 1
    s
  end
  
  def duration
    (order.auto_expire_date.to_date - order.start_date.to_date).to_i rescue nil
  end

  def self.find_common_orders(diagnosis_concept_id)
    joins = "INNER JOIN orders ON orders.order_id = drug_order.order_id AND orders.voided = 0
             INNER JOIN obs ON orders.obs_id = obs.obs_id AND obs.value_coded = #{diagnosis_concept_id}
             INNER JOIN drug ON drug.drug_id = drug_order.drug_inventory_id"             
    self.all( 
      :joins => joins, 
      :select => "*, MIN(drug_order.order_id) as order_id, COUNT(*) as number, CONCAT(drug.name, ':', dose, ' ', drug_order.units, ' ', frequency, ' for ', DATEDIFF(auto_expire_date, start_date), ' days', IF(prn=1, ' prn', '')) as script", 
      :group => ['drug.name, dose, drug_order.units, frequency, prn, DATEDIFF(start_date, auto_expire_date)'], 
      :order => "COUNT(*) DESC")
  end
  
  def self.clone_order(encounter, patient, obs, drug_order)
    write_order(encounter, patient, obs, drug_order.drug, Time.now, 
      Time.now + drug_order.duration.days, drug_order.dose, drug_order.frequency, 
      drug_order.prn)
  end

  # Eventually it would be good for this to not be hard coded, and the data available in the concept table
  def self.doses_per_day(frequency)
    return 1 if frequency == "ONCE A DAY (OD)"
    return 2 if frequency == "TWICE A DAY (BD)"
    return 3 if frequency == "THREE A DAY (TDS)"
    return 4 if frequency == "FOUR TIMES A DAY (QID)"
    return 5 if frequency == "FIVE TIMES A DAY (5X/D)"
    return 6 if frequency == "SIX TIMES A DAY (Q4HRS)"
    return 1 if frequency == "IN THE MORNING (QAM)"
    return 1 if frequency == "IN THE EVENING (QPM)"
    return 1 if frequency == "ONCE A DAY AT NIGHT (QHS)"
    return 0.5 if frequency == "EVERY OTHER DAY (QOD)"
    return 1.to_f / 7.to_f if frequency == "ONCE A WEEK (QWK)"
    return 1.to_f / 28.to_f if frequency == "ONCE A MONTH"
    return 1.to_f / 14.to_f if frequency == "TWICE A MONTH"
    1
  end
  
  # prn should be 0 | 1
  def self.write_order(encounter, patient, obs, drug, start_date, auto_expire_date, dose, frequency, prn)
    encounter ||= patient.current_treatment_encounter
    units = drug.units || 'per dose'
    duration = (auto_expire_date.to_date - start_date.to_date).to_i rescue nil
    equivalent_daily_dose = nil
    instructions = nil
    drug_order = nil       
    if (frequency == "VARIABLE")
      total_dose = dose.sum{|amount| amount.to_f rescue 0 }
      return nil if total_dose.blank?
      equivalent_daily_dose = total_dose
      instructions = "#{drug.name}:"
      instructions += " MORNING:#{dose[0]} #{units}" unless dose[0].blank? || dose[0].to_f == 0
      instructions += " AFTERNOON:#{dose[1]} #{units}" unless dose[1].blank? || dose[1].to_f == 0
      instructions += " EVENING:#{dose[2]} #{units}" unless dose[2].blank? || dose[2].to_f == 0
      instructions += " NIGHT:#{dose[3]} #{units}" unless dose[3].blank? || dose[3].to_f == 0
      instructions += " for #{duration} days" 
      instructions += " (prn)" if prn == 1
      dose = total_dose
    else
      equivalent_daily_dose = dose.to_f * DrugOrder.doses_per_day(frequency)
      instructions = "#{drug.name}: #{dose} #{units} #{frequency} for #{duration} days"
      instructions << " (prn)" if prn == 1
    end
    ActiveRecord::Base.transaction do
      order = encounter.orders.create(
        :order_type_id => 1, 
        :concept_id => drug.concept_id, 
        :orderer => User.current_user.user_id, 
        :patient_id => patient.id,
        :start_date => start_date,
        :auto_expire_date => auto_expire_date,
        :observation => obs,
        :instructions => instructions)        
      drug_order = DrugOrder.new(
        :drug_inventory_id => drug.id,
        :dose => dose,
        :frequency => frequency,
        :prn => prn,
        :units => units,
        :equivalent_daily_dose => equivalent_daily_dose)
      drug_order.order_id = order.id                
      drug_order.save!
    end             
    drug_order     
  end
  
  # We have to recalculate everything each time, because this might be the result
  # of a clinical worker voiding something. 
  def total_drug_supply(patient, encounter=nil)
    encounter ||= patient.current_dispensation_encounter
    amounts_brought = Observation.all(:conditions => 
      ['obs.voided = 0 AND ' +
       'obs.concept_id = ? AND ' +
       'obs.person_id = ? AND ' +
       'DATE(encounter.encounter_datetime) = CURRENT_DATE() AND ' +
       'encounter.voided = 0 AND ' +
       'orders.voided = 0 AND ' +
       'drug_order.drug_inventory_id = ?', 
        ConceptName.find_by_name("AMOUNT OF DRUG BROUGHT TO CLINIC").concept_id,
        patient.person.person_id,
        drug_inventory_id], 
      :include => [:encounter, [:order => :drug_order]])      
    total_brought = amounts_brought.sum{|amount| amount.value_numeric}
    amounts_dispensed = Observation.active.all(:conditions => ['concept_id = ? AND order_id = ? AND encounter_id = ?', ConceptName.find_by_name("AMOUNT DISPENSED").concept_id, self.order_id, encounter.encounter_id])
    total_dispensed = amounts_dispensed.sum{|amount| amount.value_numeric}
    total = total_dispensed + total_brought    
    obs = Observation.active.first(:conditions => ['concept_id = ? AND order_id = ? AND encounter_id = ?', ConceptName.find_by_name("TOTAL SUPPLY OF DRUG RECEIVED BY PATIENT").concept_id, self.order_id, encounter.encounter_id])
    if obs      
      obs.value_numeric = total
      obs.save
    else
      obs = Observation.create(
        :concept_name => "TOTAL SUPPLY OF DRUG RECEIVED BY PATIENT",
        :order_id => self.order_id,
        :person_id => patient.person.person_id,
        :encounter_id => encounter.id,
        :value_drug => self.drug_inventory_id,
        :value_numeric => total,
        :obs_datetime => Time.now)    
    end
    [amounts_dispensed, obs]
  end
end