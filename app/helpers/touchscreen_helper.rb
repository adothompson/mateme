# Methods added to this helper will be available to all templates in the application.
module TouchscreenHelper

  def touch_meta_tag(concept, patient, time=DateTime.now(), kind=nil)
    content = ""
    content << hidden_field_tag("observations[][value_numeric]", nil) unless kind == 'value_numeric'
    content << hidden_field_tag("observations[][value_datetime]", nil) unless kind == 'value_datetime'
    content << hidden_field_tag("observations[][value_coded_or_text]", nil) unless kind == 'value_coded_or_text'
    content << hidden_field_tag("observations[][value_coded]", nil)  unless kind == 'value_coded'
    content << hidden_field_tag("observations[][value_text]", nil)  unless kind == 'value_text'
    content << hidden_field_tag("observations[][value_boolean]", nil)  unless kind == 'value_boolean'
    content << hidden_field_tag("observations[][value_drug]", nil)  unless kind == 'value_drug'
    content << hidden_field_tag("observations[][concept_name]", concept) 
    content << hidden_field_tag("observations[][patient_id]", patient.id) 
    content << hidden_field_tag("observations[][obs_datetime]", time)
    content
  end  

  def touch_date_tag(concept, patient, value, options={}, time=DateTime.now())
    options = {
      :field_type => 'date',   
      :tt_pageStyleClass => "Date DatesOnly"
    }.merge(options)                 
    content = ""
    content << text_field_tag("observations[][value_datetime]", value, options) 
    content << touch_meta_tag(concept, patient, time, 'value_datetime')
    content
  end

  def touch_numeric_tag(concept, patient, value, options={}, time=DateTime.now())
    options = {
      :field_type => 'number',
      :validationRule => "^([0-9]+)|Unknown$",
      :validationMessage => "You must enter numbers only (for example 90)",
      :tt_pageStyleClass => "Numeric NumbersOnly"
    }.merge(options)                 
    content = ""
    content << text_field_tag("observations[][value_numeric]", value, options) 
    content << touch_meta_tag(concept, patient, time, 'value_numeric')
    content
  end

  def touch_text_field_tag(concept, patient, value, options={}, time=DateTime.now())
    options = {
      :field_type => 'alpha',
      :allowFreeText => true
    }.merge(options)                 
    content = ""
    content << text_field_tag("observations[][value_text]", value, options) 
    content << touch_meta_tag(concept, patient, time, 'value_text')
    content
  end

  def touch_location_tag(concept, patient, value, options={}, time=DateTime.now())
    options = {
      :field_type => 'alpha',
      :ajaxURL => '/programs/locations?q=', 
      :allowFreeText => true
    }.merge(options)                 
    touch_text_field_tag(concept, patient, value, options, time)
  end

  def touch_options_tag(concept, patient, values, options={}, time=DateTime.now())
    content = ""
    content << text_field_tag("observations[][value_text]", values, options) 
    content << touch_meta_tag(concept, patient, time, 'value_text')
    content
  end

  def touch_select_tag(concept, patient, choices, options={}, time=DateTime.now())
    options = {  
     :allowFreeText => false 
    }.merge(options)                 
    content = ""
    content << select_tag("observations[][value_coded_or_text]", choices, options) 
    content << touch_meta_tag(concept, patient, time, 'value_coded_or_text')
    content
  end

  def touch_boolean_tag(concept, patient, value, options={}, time=DateTime.now())
    touch_select_tag(concept, patient, options_for_select([['Yes','YES'],['No','NO']], value), options, time)
  end
  
  def touch_yes_no_unknown_tag(concept, patient, value, options={}, time=DateTime.now())
    touch_select_tag(concept, patient, options_for_select([['Yes','YES'],['No','NO'],['Unknown','UNKNOWN']], value), options, time)
  end
  
  def touch_yes_no_tag(concept, patient, value, options={}, time=DateTime.now())
    touch_select_tag(concept, patient, options_for_select([['Yes','YES'],['No','NO']], value), options, time)
  end
  
  def touch_hidden_tag(concept, patient, value, options={}, time=DateTime.now())
    options = {  
     :allowFreeText => false 
    }.merge(options)                 
    content = ""
    content << hidden_tag("observations[][value_coded_or_text]", value, options) 
    content << touch_meta_tag(concept, patient, time, 'value_coded_or_text')
    content
  end
end