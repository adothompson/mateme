class EncountersController < ApplicationController

  def create  
    @patient = Patient.find(params[:encounter][:patient_id])
    # Encounter handling
    encounter = Encounter.new(params[:encounter])
    encounter.encounter_datetime = session[:datetime] unless session[:datetime].blank?
    encounter.save    
    # Observation handling
    (params[:observations] || []).each do |observation|
      # Check to see if any values are part of this observation
      # This keeps us from saving empty observations
      values = ['coded_or_text', 'group_id', 'boolean', 'coded', 'drug', 'datetime', 'numeric', 'modifier', 'text'].map{|value_name|
        observation["value_#{value_name}"] unless observation["value_#{value_name}"].blank? rescue nil
      }.compact
      next if values.length == 0
      observation[:value_text] = observation[:value_text].join(", ") if observation[:value_text].present? && observation[:value_text].is_a?(Array)
      observation.delete(:value_text) unless observation[:value_coded_or_text].blank?
      observation[:encounter_id] = encounter.id
      observation[:obs_datetime] = encounter.encounter_datetime || Time.now()
      observation[:person_id] ||= encounter.patient_id
      observation[:concept_name] ||= "OUTPATIENT DIAGNOSIS" if encounter.type.name == "OUTPATIENT DIAGNOSIS"
      # Handle multiple select
      if observation[:value_coded_or_text] && observation[:value_coded_or_text].is_a?(Array)
        values = observation[:value_coded_or_text]
        values.each{|value| observation[:value_coded_or_text] = value; Observation.create(observation) }
      else      
        Observation.create(observation)
      end
    end
    # Program handling
    (params[:programs] || []).each do |program|
      # Look up the program if the program id is set      
      @patient_program = PatientProgram.find(program[:patient_program_id]) unless program[:patient_program_id].blank?
      # If it wasn't set, we need to create it
      unless (@patient_program)
        @patient_program = @patient.patient_programs.create(
          :program_id => program[:program_id],
          :date_enrolled => program[:date_enrolled] || Time.now)          
      end
      # Lots of states bub
      (program[:states] || []).each {|state| @patient_program.transition(state) }
    end
    # Go to the next task in the workflow (or dashboard)
    redirect_to next_task(@patient) 
  end

  def new
    @patient = Patient.find(params[:patient_id] || session[:patient_id]) 
    redirect_to "/" and return unless @patient
    redirect_to next_task(@patient) and return unless params[:encounter_type]
    redirect_to :action => :create, 'encounter[encounter_type_name]' => params[:encounter_type].upcase, 'encounter[patient_id]' => @patient.id and return if ['registration'].include?(params[:encounter_type])
    render :action => params[:encounter_type] if params[:encounter_type]
  end

  def diagnoses
    search_string = (params[:search_string] || '').upcase
    filter_list = params[:filter_list].split(/, */) rescue []
    outpatient_diagnosis = ConceptName.find_by_name("OUTPATIENT DIAGNOSIS").concept
    diagnosis_concepts = ConceptClass.find_by_name("DIAGNOSIS", :include => {:concepts => :name}).concepts rescue []    
    # TODO Need to check a global property for which concept set to limit things to
    if (false)
      diagnosis_concept_set = ConceptName.find_by_name('MALAWI NATIONAL DIAGNOSIS').concept
      diagnosis_concepts = Concept.find(:all, :joins => :concept_sets, :conditions => ['concept_set = ?', concept_set.id], :include => [:name])
    end  
    valid_answers = diagnosis_concepts.map{|concept| 
      name = concept.name.name rescue nil
      name.match(search_string) ? name : nil rescue nil
    }.compact
    previous_answers = []
    # TODO Need to check global property to find out if we want previous answers or not (right now we)
    previous_answers = Observation.find_most_common(outpatient_diagnosis, search_string)
    @suggested_answers = (previous_answers + valid_answers).reject{|answer| filter_list.include?(answer) }.uniq[0..10] 
    render :text => "<li>" + @suggested_answers.join("</li><li>") + "</li>"
  end

  def treatment
    search_string = (params[:search_string] || '').upcase
    filter_list = params[:filter_list].split(/, */) rescue []
    valid_answers = []
    unless search_string.blank?
      drugs = Drug.find(:all, :conditions => ["retired = 0 AND name LIKE ?", '%' + search_string + '%'])
      valid_answers = drugs.map {|drug| drug.name.upcase }
    end
    treatment = ConceptName.find_by_name("TREATMENT").concept
    previous_answers = Observation.find_most_common(treatment, search_string)
    suggested_answers = (previous_answers + valid_answers).reject{|answer| filter_list.include?(answer) }.uniq[0..10] 
    render :text => "<li>" + suggested_answers.join("</li><li>") + "</li>"
  end
  
  def locations
    search_string = (params[:search_string] || 'neno').upcase
    filter_list = params[:filter_list].split(/, */) rescue []    
    locations =  Location.find(:all, :select =>'name', :conditions => ["retired = 0 AND name LIKE ?", '%' + search_string + '%'])
    render :text => "<li>" + locations.map{|location| location.name }.join("</li><li>") + "</li>"
  end

  def observations
    # We could eventually include more here, maybe using a scope with includes
    @encounter = Encounter.find(params[:id], :include => [:observations])
    render :layout => false
  end

  def void 
    @encounter = Encounter.find(params[:id], :include => [:observations])
    ActiveRecord::Base.transaction do
      @encounter.observations.each{|obs| obs.void!}
      @encounter.void!
    end
    head :ok
  end
end
