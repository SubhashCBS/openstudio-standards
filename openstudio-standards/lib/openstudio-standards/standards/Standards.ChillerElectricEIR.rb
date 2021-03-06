
# Reopen the OpenStudio class to add methods to apply standards to this object
class OpenStudio::Model::ChillerElectricEIR

  # Finds the search criteria
  #
  # @param template [String] valid choices: 'DOE Ref Pre-1980', 'DOE Ref 1980-2004', '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
  # @return [hash] has for search criteria to be used for find object
  def find_search_criteria(template)

    # Define the criteria to find the chiller properties
    # in the hvac standards data set.
    search_criteria = {}
    search_criteria['template'] = template
    cooling_type = self.condenserType
    search_criteria['cooling_type'] = cooling_type

    # TODO Standards replace this with a mechanism to store this
    # data in the chiller object itself.
    # For now, retrieve the condenser type from the name
    name = self.name.get
    condenser_type = nil
    compressor_type = nil
    if name.include?('AirCooled')
      if name.include?('WithCondenser')
        condenser_type = 'WithCondenser'
      elsif name.include?('WithoutCondenser')
        condenser_type = 'WithoutCondenser'
      end
    elsif name.include?('WaterCooled')
      if name.include?('Reciprocating')
        compressor_type = 'Reciprocating'
      elsif name.include?('Rotary Screw')
        compressor_type = 'Rotary Screw'
      elsif  name.include?('Scroll')
        compressor_type = 'Scroll'
      elsif name.include?('Centrifugal')
        compressor_type = 'Centrifugal'
      end
    end
    unless condenser_type.nil?
      search_criteria['condenser_type'] = condenser_type
    end
    unless compressor_type.nil?
      search_criteria['compressor_type'] = compressor_type
    end

    return search_criteria

  end

  # Finds capacity in tons
  #
  # @return [Double] capacity in tons to be used for find object
  def find_capacity()

    # Get the chiller capacity
    capacity_w = nil
    if self.referenceCapacity.is_initialized
      capacity_w = self.referenceCapacity.get
    elsif self.autosizedReferenceCapacity.is_initialized
      capacity_w = self.autosizedReferenceCapacity.get
    else
      OpenStudio::logFree(OpenStudio::Warn, "openstudio.standards.ChillerElectricEIR", "For #{self.name} capacity is not available, cannot apply efficiency standard.")
      successfully_set_all_properties = false
      return successfully_set_all_properties
    end

    capacity_tons = OpenStudio.convert(capacity_w, "W", "ton").get


    return capacity_tons

  end

  # Finds lookup object in standards and return full load efficiency
  #
  # @param template [String] valid choices: 'DOE Ref Pre-1980', 'DOE Ref 1980-2004', '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
  # @param standards [Hash] the OpenStudio_Standards spreadsheet in hash format
  # @return [Double] full load efficiency (COP)
  def standard_minimum_full_load_efficiency(template,standards)

    # Get the chiller properties
    search_criteria = self.find_search_criteria(template)
    capacity_tons = self.find_capacity
    chlr_props = self.model.find_object(standards['chillers'], search_criteria, capacity_tons)

    # lookup the efficiency value
    kw_per_ton = nil
    cop = nil
    if chlr_props['minimum_full_load_efficiency']
      kw_per_ton = chlr_props['minimum_full_load_efficiency']
      cop = kw_per_ton_to_cop(kw_per_ton)
    else
      OpenStudio::logFree(OpenStudio::Warn, "openstudio.standards.ChillerElectricEIR", "For #{self.name}, cannot find minimum full load efficiency.")
    end

    return cop

  end

  # Applies the standard efficiency ratings and typical performance curves to this object.
  #
  # @param template [String] valid choices: 'DOE Ref Pre-1980', 'DOE Ref 1980-2004', '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
  # @param standards [Hash] the OpenStudio_Standards spreadsheet in hash format
  # @return [Bool] true if successful, false if not
  def setStandardEfficiencyAndCurves(template, clg_tower_objs)

    chillers = $os_standards['chillers']
    curve_biquadratics = $os_standards['curve_biquadratics']
    curve_quadratics = $os_standards['curve_quadratics']
    curve_bicubics = $os_standards['curve_bicubics']


    # Define the criteria to find the chiller properties
    # in the hvac standards data set.
    search_criteria = {}
    search_criteria['template'] = template
    cooling_type = self.condenserType
    search_criteria['cooling_type'] = cooling_type

    # TODO Standards replace this with a mechanism to store this
    # data in the chiller object itself.
    # For now, retrieve the condenser type from the name
    name = self.name.get
    condenser_type = nil
    compressor_type = nil
    if name.include?('AirCooled')
      if name.include?('WithCondenser')
        condenser_type = 'WithCondenser'
      elsif name.include?('WithoutCondenser')
        condenser_type = 'WithoutCondenser'
      end
    elsif name.include?('WaterCooled')
      if name.include?('Reciprocating')
        compressor_type = 'Reciprocating'
      elsif name.include?('Rotary Screw')
        compressor_type = 'Rotary Screw'
      elsif  name.include?('Scroll')
        compressor_type = 'Scroll'
      elsif name.include?('Centrifugal')
        compressor_type = 'Centrifugal'
      end
    end
    unless condenser_type.nil?
      search_criteria['condenser_type'] = condenser_type
    end
    unless compressor_type.nil?
      search_criteria['compressor_type'] = compressor_type
    end

    # Get the chiller capacity
    capacity_w = nil
    if self.referenceCapacity.is_initialized
      capacity_w = self.referenceCapacity.get
    elsif self.autosizedReferenceCapacity.is_initialized
      capacity_w = self.autosizedReferenceCapacity.get
    else
      OpenStudio::logFree(OpenStudio::Warn, "openstudio.standards.ChillerElectricEIR", "For #{self.name} capacity is not available, cannot apply efficiency standard.")
      successfully_set_all_properties = false
      return successfully_set_all_properties
    end

    #NECB 2011 requires that all chillers be modulating down to 25% of their capacity
    if template == 'NECB 2011'
      self.setChillerFlowMode('LeavingSetpointModulated')
      self.setMinimumPartLoadRatio(0.25)
      self.setMinimumUnloadingRatio(0.25)
      if((capacity_w/1000.0) < 2100.0)
        if(self.name.to_s.include? 'Primary Chiller')
          chiller_capacity = capacity_w
        elsif(self.name.to_s.include? 'Secondary Chiller')
          chiller_capacity = 0.001
        end
      else
        chiller_capacity = capacity_w/2.0
      end
      self.setReferenceCapacity(chiller_capacity)
    end  # NECB 2011

    # Convert capacity to tons
    if template == 'NECB 2011'
      capacity_tons = OpenStudio.convert(chiller_capacity, "W", "ton").get
    else
      capacity_tons = OpenStudio.convert(capacity_w, "W", "ton").get
    end

    # Get the chiller properties
    chlr_props = self.model.find_object(chillers, search_criteria, capacity_tons)
    if !chlr_props
      OpenStudio::logFree(OpenStudio::Warn, "openstudio.standards.ChillerElectricEIR", "For #{self.name}, cannot find chiller properties, cannot apply standard efficiencies or curves.")
      successfully_set_all_properties = false
      return successfully_set_all_properties
    end

    # Make the CAPFT curve
    cool_cap_ft = self.model.add_curve(chlr_props['capft'])
    if cool_cap_ft
      self.setCoolingCapacityFunctionOfTemperature(cool_cap_ft)
    else
      OpenStudio::logFree(OpenStudio::Warn, "openstudio.standards.ChillerElectricEIR", "For #{self.name}, cannot find cool_cap_ft curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Make the EIRFT curve
    cool_eir_ft = self.model.add_curve(chlr_props['eirft'])
    if cool_eir_ft
      self.setElectricInputToCoolingOutputRatioFunctionOfTemperature(cool_eir_ft)
    else
      OpenStudio::logFree(OpenStudio::Warn, "openstudio.standards.ChillerElectricEIR", "For #{self.name}, cannot find cool_eir_ft curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Make the EIRFPLR curve
    # which may be either a CurveBicubic or a CurveQuadratic based on chiller type
    cool_plf_fplr = self.model.add_curve(chlr_props['eirfplr'])
    if cool_plf_fplr
      self.setElectricInputToCoolingOutputRatioFunctionOfPLR(cool_plf_fplr)
    else
      OpenStudio::logFree(OpenStudio::Warn, "openstudio.standards.ChillerElectricEIR", "For #{self.name}, cannot find cool_plf_fplr curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Set the efficiency value
    kw_per_ton = nil
    cop = nil
    if chlr_props['minimum_full_load_efficiency']
      kw_per_ton = chlr_props['minimum_full_load_efficiency']
      cop = kw_per_ton_to_cop(kw_per_ton)
      self.setReferenceCOP(cop)
    else
      OpenStudio::logFree(OpenStudio::Warn, "openstudio.standards.ChillerElectricEIR", "For #{self.name}, cannot find minimum full load efficiency, will not be set.")
      successfully_set_all_properties = false
    end

    # Set cooling tower properties for NECB 2011 now that the new COP of the chiller is set
    if template == 'NECB 2011'
      if(self.name.to_s.include? 'Primary Chiller')
        # Single speed tower model assumes 25% extra for compressor power
        tower_cap = capacity_w*(1.0+1.0/self.referenceCOP)
        if((tower_cap/1000.0) < 1750)
          clg_tower_objs[0].setNumberofCells(1)
        else
          clg_tower_objs[0].setNumberofCells((tower_cap/(1000*1750)+0.5).round)
        end
        clg_tower_objs[0].setFanPoweratDesignAirFlowRate(0.015*tower_cap)
      end
    end

    # Append the name with size and kw/ton
    self.setName("#{name} #{capacity_tons.round}tons #{kw_per_ton.round(1)}kW/ton")
    OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.ChillerElectricEIR', "For #{template}: #{self.name}: #{cooling_type} #{condenser_type} #{compressor_type} Capacity = #{capacity_tons.round}tons; COP = #{cop.round(1)} (#{kw_per_ton.round(1)}kW/ton)")

    return successfully_set_all_properties

  end

end
