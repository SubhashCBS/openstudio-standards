require_relative 'minitest_helper'


# This class will perform tests that are HDD driven, A Test model will be created
# that will have all of OpenStudios surface types with different contructions. All
# components are created from scratch to ensure model are up to date and we will
# not run into version issues with the test. 
# to specifically test aspects of the NECB2011 code that are HDD dependant. 
class NECBHDDTests < Minitest::Test
  #set global weather files sample
  NECB_epw_files_for_cdn_climate_zones = [
    'CAN_BC_Vancouver.718920_CWEC.epw',#  CZ 5 - Gas HDD = 3019 
    'CAN_ON_Toronto.716240_CWEC.epw', #CZ 6 - Gas HDD = 4088
    'CAN_PQ_Sherbrooke.716100_CWEC.epw', #CZ 7a - Electric HDD = 5068
    'CAN_YT_Whitehorse.719640_CWEC.epw', #CZ 7b - FuelOil1 HDD = 6946
    'CAN_NU_Resolute.719240_CWEC.epw' # CZ 8  -FuelOil2 HDD = 12570
  ] 
  #Set Compliance vintage
  Templates = ['NECB 2011']#,'90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013']
  
  # Create scaffolding to create a model with windows, then reset to appropriate values.
  # Will require large windows and constructions that have high U-values.    
  def setup()

    #Create new model for testing. 
    @model = OpenStudio::Model::Model.new
    #Create Geometry that will be used for all tests.  
    
    #Below ground story to tests all ground surfaces including roof.
    length = 100.0; width = 100.0 ; num_above_ground_floors = 0; num_under_ground_floors = 1; floor_to_floor_height = 3.8 ; plenum_height = 1; perimeter_zone_depth = 4.57; initial_height = -10.0
    BTAP::Geometry::Wizards::create_shape_rectangle(@model,length, width, num_above_ground_floors,num_under_ground_floors, floor_to_floor_height, plenum_height,perimeter_zone_depth, initial_height )

    #Above ground story to test all above outdoors surfaces including floor.
    length = 100.0; width = 100.0 ; num_above_ground_floors = 3; num_under_ground_floors = 0; floor_to_floor_height = 3.8 ; plenum_height = 1; perimeter_zone_depth = 4.57; initial_height = 10.0
    BTAP::Geometry::Wizards::create_shape_rectangle(@model,length, width, num_above_ground_floors,num_under_ground_floors, floor_to_floor_height, plenum_height,perimeter_zone_depth, initial_height )

    #Find all outdoor surfaces. 
    outdoor_surfaces = BTAP::Geometry::Surfaces::filter_by_boundary_condition(@model.getSurfaces(), "Outdoors")
    @outdoor_walls = BTAP::Geometry::Surfaces::filter_by_surface_types(outdoor_surfaces, "Wall")
    @outdoor_roofs = BTAP::Geometry::Surfaces::filter_by_surface_types(outdoor_surfaces, "RoofCeiling")
    
    #Set all FWDR to a ratio of 0.60
    subsurfaces = []
    counter = 0
    @outdoor_walls.each {|wall| subsurfaces << wall.setWindowToWallRatio(0.60) }
    #ensure all wall subsurface types are represented. 
    subsurfaces.each do |subsurface|
      counter = counter + 1

      case counter
      when 1
        subsurface.get.setSubSurfaceType('FixedWindow')
      when 2
        subsurface.get.setSubSurfaceType('OperableWindow')
      when 3
        subsurface.get.setSubSurfaceType('Door')
      when 4
        subsurface.get.setSubSurfaceType('GlassDoor')
        counter = 0
      end
    end
        

    #Create skylights that are 10% of area with a 4x4m size.
    pattern = OpenStudio::Model::generateSkylightPattern(@model.getSpaces,@model.getSpaces[0].directionofRelativeNorth,0.10, 4.0, 4.0) # ratio, x value, y value
    subsurfaces = OpenStudio::Model::applySkylightPattern(pattern, @model.getSpaces, OpenStudio::Model::OptionalConstructionBase.new)
    
    #ensure all roof subsurface types are represented. 
    subsurfaces.each do |subsurface|
      counter = counter + 1
      case counter
      when 1
        subsurface.setSubSurfaceType('Skylight')
      when 2
        subsurface.setSubSurfaceType('TubularDaylightDome')
      when 3
        subsurface.setSubSurfaceType('TubularDaylightDiffuser')
      when 4
        subsurface.setSubSurfaceType('OverheadDoor')
        counter = 0
      end
    end

  end #setup()
  

  
  # Tests to ensure that the U-Values of the construction are set correctly. This 
  # test will set up  
  # for all HDDs 
  # NECB 2011 8.4.4.1
  # @return [Bool] true if successful. 
  def test_necb_hdd_envelope_rules()
    # Todo - Define a construction directly to a surface. 
    # Todo - Define a construction set to a space directly.
    # Todo - Define a construction set to a floor directly. 
    # Todo - Define an adiabatic surface (See if it handle the bug)
    # Todo - Roughly 1 day of work (phylroy) 
     
    #Create report string. 
    @output = ""
    @output << "Vintage,WeatherFile,HDD,FDWR,SRR," 
    @output << "outdoor_walls_average_conductance,outdoor_roofs_average_conductance,outdoor_floors_average_conductance,"
    @output << "ground_walls_average_conductances, ground_roofs_average_conductances, ground_floors_average_conductances,"
    @output << "windows_average_conductance,skylights_average_conductance,doors_average_conductance,overhead_doors_average_conductance\n"
     
    
    #Iterate through the weather files. 
    NECB_epw_files_for_cdn_climate_zones.each do |weather_file|
      @hdd = BTAP::Environment::WeatherFile.new(weather_file).hdd18
      #Iterate through the vintage templates 'NECB 2011', etc..
      Templates.each do |template|
      
        #Define Materials
        name = "opaque material";      thickness = 0.012700; conductivity = 0.160000
        opaque_mat     = BTAP::Resources::Envelope::Materials::Opaque::create_opaque_material( @model, name, thickness, conductivity)
    
        name = "insulation material";  thickness = 0.050000; conductivity = 0.043000
        insulation_mat = BTAP::Resources::Envelope::Materials::Opaque::create_opaque_material( @model,name, thickness, conductivity)
    
        name = "simple glazing test";shgc  = 0.250000 ; ufactor = 3.236460; thickness = 0.003000; visible_transmittance = 0.160000
        simple_glazing_mat = BTAP::Resources::Envelope::Materials::Fenestration::create_simple_glazing(@model,name,shgc,ufactor,thickness,visible_transmittance)
    
        name = "Standard Glazing Test"; thickness = 0.003; conductivity = 0.9; solarTransmittanceatNormalIncidence = 0.84; frontSideSolarReflectanceatNormalIncidence = 0.075; backSideSolarReflectanceatNormalIncidence = 0.075; visibleTransmittance = 0.9; frontSideVisibleReflectanceatNormalIncidence = 0.081; backSideVisibleReflectanceatNormalIncidence = 0.081; infraredTransmittanceatNormalIncidence = 0.0; frontSideInfraredHemisphericalEmissivity = 0.84; backSideInfraredHemisphericalEmissivity = 0.84; opticalDataType = "SpectralAverage"; dirt_correction_factor = 1.0; is_solar_diffusing = false
        standard_glazing_mat =BTAP::Resources::Envelope::Materials::Fenestration::create_standard_glazing( @model, name ,thickness, conductivity, solarTransmittanceatNormalIncidence, frontSideSolarReflectanceatNormalIncidence, backSideSolarReflectanceatNormalIncidence, visibleTransmittance, frontSideVisibleReflectanceatNormalIncidence, backSideVisibleReflectanceatNormalIncidence, infraredTransmittanceatNormalIncidence, frontSideInfraredHemisphericalEmissivity, backSideInfraredHemisphericalEmissivity,opticalDataType, dirt_correction_factor, is_solar_diffusing)
    
        #Define Constructions
        # # Surfaces 
        ext_wall                            = BTAP::Resources::Envelope::Constructions::create_construction(@model, "OpaqueConstructionExtWall",                    [opaque_mat,insulation_mat], insulation_mat)
        ext_roof                            = BTAP::Resources::Envelope::Constructions::create_construction(@model, "OpaqueConstructionExtRoof",                    [opaque_mat,insulation_mat], insulation_mat)
        ext_floor                           = BTAP::Resources::Envelope::Constructions::create_construction(@model, "OpaqueConstructionExtFloor",                   [opaque_mat,insulation_mat], insulation_mat)
        grnd_wall                           = BTAP::Resources::Envelope::Constructions::create_construction(@model, "OpaqueConstructionGrndWall",                   [opaque_mat,insulation_mat], insulation_mat)
        grnd_roof                           = BTAP::Resources::Envelope::Constructions::create_construction(@model, "OpaqueConstructionGrndRoof",                   [opaque_mat,insulation_mat], insulation_mat)
        grnd_floor                          = BTAP::Resources::Envelope::Constructions::create_construction(@model, "OpaqueConstructionGrndFloor",                  [opaque_mat,insulation_mat], insulation_mat)
        int_wall                            = BTAP::Resources::Envelope::Constructions::create_construction(@model, "OpaqueConstructionIntWall",                    [opaque_mat,insulation_mat], insulation_mat)
        int_roof                            = BTAP::Resources::Envelope::Constructions::create_construction(@model, "OpaqueConstructionIntRoof",                    [opaque_mat,insulation_mat], insulation_mat)
        int_floor                           = BTAP::Resources::Envelope::Constructions::create_construction(@model, "OpaqueConstructionIntFloor",                   [opaque_mat,insulation_mat], insulation_mat)
        # # Subsurfaces
        fixedWindowConstruction             = BTAP::Resources::Envelope::Constructions::create_construction(@model, "FenestrationConstructionFixed",                [simple_glazing_mat])
        operableWindowConstruction          = BTAP::Resources::Envelope::Constructions::create_construction(@model, "FenestrationConstructionOperable",             [simple_glazing_mat])
        setGlassDoorConstruction            = BTAP::Resources::Envelope::Constructions::create_construction(@model, "FenestrationConstructionDoor",                 [standard_glazing_mat])
        setDoorConstruction                 = BTAP::Resources::Envelope::Constructions::create_construction(@model, "OpaqueConstructionDoor",                       [opaque_mat,insulation_mat], insulation_mat)
        overheadDoorConstruction            = BTAP::Resources::Envelope::Constructions::create_construction(@model, "OpaqueConstructionOverheadDoor",               [opaque_mat,insulation_mat], insulation_mat)
        skylightConstruction                = BTAP::Resources::Envelope::Constructions::create_construction(@model, "FenestrationConstructionSkylight",             [standard_glazing_mat])
        tubularDaylightDomeConstruction     = BTAP::Resources::Envelope::Constructions::create_construction(@model, "FenestrationConstructionDomeConstruction",     [standard_glazing_mat])
        tubularDaylightDiffuserConstruction = BTAP::Resources::Envelope::Constructions::create_construction(@model, "FenestrationConstructionDiffuserConstruction", [standard_glazing_mat])
    
        #Define Construction Sets
        # # Surface
        exterior_construction_set = BTAP::Resources::Envelope::ConstructionSets::create_default_surface_constructions( @model,"ExteriorSet",ext_wall,ext_roof,ext_floor)
        interior_construction_set = BTAP::Resources::Envelope::ConstructionSets::create_default_surface_constructions( @model,"InteriorSet",int_wall,int_roof,int_floor)
        ground_construction_set   = BTAP::Resources::Envelope::ConstructionSets::create_default_surface_constructions( @model,"GroundSet",  grnd_wall,grnd_roof,grnd_floor)
    
        # # Subsurface 
        subsurface_exterior_construction_set = BTAP::Resources::Envelope::ConstructionSets::create_subsurface_construction_set( @model, fixedWindowConstruction, operableWindowConstruction, setDoorConstruction, setGlassDoorConstruction, overheadDoorConstruction, skylightConstruction, tubularDaylightDomeConstruction, tubularDaylightDiffuserConstruction)
        subsurface_interior_construction_set = BTAP::Resources::Envelope::ConstructionSets::create_subsurface_construction_set( @model, fixedWindowConstruction, operableWindowConstruction, setDoorConstruction, setGlassDoorConstruction, overheadDoorConstruction, skylightConstruction, tubularDaylightDomeConstruction, tubularDaylightDiffuserConstruction)
    
        #Define default construction sets.
        name = "Construction Set 1"
        default_construction_set = BTAP::Resources::Envelope::ConstructionSets::create_default_construction_set(@model, name, exterior_construction_set, interior_construction_set, ground_construction_set, subsurface_exterior_construction_set, subsurface_interior_construction_set)

    
        #Assign default to the model. 
        @model.getBuilding.setDefaultConstructionSet( default_construction_set )
      
        #Add weather file, HDD.
        @model.add_design_days_and_weather_file('HighriseApartment', template, 'NECB HDD Method', File.basename(weather_file))
      
        # Reduce the WWR and SRR, if necessary
        @model.apply_performance_rating_method_baseline_window_to_wall_ratio(template)
        @model.apply_performance_rating_method_baseline_skylight_to_roof_ratio(template)
        
        # Apply Construction
        @model.apply_performance_rating_method_construction_types(template)

      
        #Get Surfaces by type.
        outdoor_surfaces = BTAP::Geometry::Surfaces::filter_by_boundary_condition(@model.getSurfaces(), "Outdoors")
        outdoor_walls = BTAP::Geometry::Surfaces::filter_by_surface_types(outdoor_surfaces, "Wall")
        outdoor_roofs = BTAP::Geometry::Surfaces::filter_by_surface_types(outdoor_surfaces, "RoofCeiling")
        outdoor_floors = BTAP::Geometry::Surfaces::filter_by_surface_types(outdoor_surfaces, "Floor")
        outdoor_subsurfaces = BTAP::Geometry::Surfaces::get_subsurfaces_from_surfaces(outdoor_surfaces)
        windows = BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(outdoor_subsurfaces, ["FixedWindow" , "OperableWindow" ])
        skylights = BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(outdoor_subsurfaces, ["Skylight", "TubularDaylightDiffuser","TubularDaylightDome" ])
        doors = BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(outdoor_subsurfaces, ["Door" , "GlassDoor" ])
        overhead_doors = BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(outdoor_subsurfaces, ["OverheadDoor" ])
        ground_surfaces = BTAP::Geometry::Surfaces::filter_by_boundary_condition(@model.getSurfaces(), "Ground")
        ground_walls = BTAP::Geometry::Surfaces::filter_by_surface_types(ground_surfaces, "Wall")
        ground_roofs = BTAP::Geometry::Surfaces::filter_by_surface_types(ground_surfaces, "RoofCeiling")
        ground_floors = BTAP::Geometry::Surfaces::filter_by_surface_types(ground_surfaces, "Floor")
      
        #Determine the weighted average conductances by surface type. 
        ## exterior surfaces
        outdoor_walls_average_conductance = BTAP::Geometry::Surfaces::get_weighted_average_surface_conductance(outdoor_walls)
        outdoor_roofs_average_conductance = BTAP::Geometry::Surfaces::get_weighted_average_surface_conductance(outdoor_roofs)
        outdoor_floors_average_conductance = BTAP::Geometry::Surfaces::get_weighted_average_surface_conductance(outdoor_floors)
        ## Ground surfaces
        ground_walls_average_conductances = BTAP::Geometry::Surfaces::get_weighted_average_surface_conductance(ground_walls)
        ground_roofs_average_conductances = BTAP::Geometry::Surfaces::get_weighted_average_surface_conductance(ground_roofs)
        ground_floors_average_conductances = BTAP::Geometry::Surfaces::get_weighted_average_surface_conductance(ground_floors)
        ## Sub surfaces
        windows_average_conductance = BTAP::Geometry::Surfaces::get_weighted_average_surface_conductance(windows)
        skylights_average_conductance = BTAP::Geometry::Surfaces::get_weighted_average_surface_conductance(skylights)
        doors_average_conductance = BTAP::Geometry::Surfaces::get_weighted_average_surface_conductance(doors)
        overhead_doors_average_conductance = BTAP::Geometry::Surfaces::get_weighted_average_surface_conductance(overhead_doors)

        #Save information to report. Rounding is done to avoid floating point small differences. 
        @output << "#{template},#{weather_file},#{@hdd.round(0)},#{BTAP::Geometry::get_fwdr(@model).round(4)},#{BTAP::Geometry::get_srr(@model).round(4)},"
        @output << "#{outdoor_walls_average_conductance.round(4)} ,#{outdoor_roofs_average_conductance.round(4)} , #{outdoor_floors_average_conductance.round(4)},"
        @output << "#{ground_walls_average_conductances.round(4)},#{ground_roofs_average_conductances.round(4)},#{ground_floors_average_conductances.round(4)},"
        @output << "#{windows_average_conductance.round(4)},#{skylights_average_conductance.round(4)},#{doors_average_conductance.round(4)},#{overhead_doors_average_conductance.round(4)}\n"
        BTAP::FileIO::save_osm(@model, File.join(File.dirname(__FILE__),"output","#{template}-hdd#{@hdd}-envelope_test.osm"))
      end #Weather file loop.
    end # Template vintage loop
    
    #Write test report file. 
    test_result_file = File.join(File.dirname(__FILE__),'regression_files','compliance_envelope_test_results.csv')
    File.open(test_result_file, 'w') {|f| f.write(@output) }
    
    #Test that the values are correct by doing a file compare.
    expected_result_file = File.join(File.dirname(__FILE__),'regression_files','compliance_envelope_expected_results.csv')
    b_result = FileUtils.compare_file(expected_result_file , test_result_file )
    BTAP::FileIO::save_osm(@model, File.join(File.dirname(__FILE__),'envelope_test.osm'))
    assert( b_result, 
      "Envelope test results do not match expected results! Compare/diff the output with the stored values here #{expected_result_file} and #{test_result_file}"
    )  
  end # test_envelope()
      
      
    
    
end #Class NECBHDDTests


# This class will perform tests that are Spacetype dependant, Test model will be created
# to specifically test aspects of the NECB2011 code that are Spacetype dependant. 
class NECB2011DefaultSpaceTypeTests < Minitest::Test
  #Standards
  Templates = ['NECB 2011']#,'90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013']
  #NECB Building Spacetype definition names. 
  BuildingTypeNames = [
    "Automotive facility",
    "Convention centre",
    "Courthouse",
    "Dining - bar/lounge",
    "Dining - cafeteria",
    "Dining - family",
    "Dormitory",
    "Exercise centre",
    "Fire station",
    "Gymnasium",
    "Health-care clinic",
    "Hospital",
    "Hotel",
    "Library",
    "Manufacturing facility",
    "Motel",
    "Motion picture theatre",
    "Multi-unit residential",
    "Museum",
    "Office",
    "Parking garage",
    "Penitentiary",
    "Performing arts theatre",
    "Police station",
    "Post office",
    "Religious",
    "Retail",
    "School/university",
    "Sports arena",
    "Town hall",
    "Transportation",
    "Warehouse",
    "Workshop",
  ]

  #NECB Spacetype definition names. 
  SpaceTypeNames = [
    "- undefined -",
    "Dwelling Unit(s)",
    "Atrium - H < 13m",
    "Atrium - H > 13m",
    "Audience - auditorium",
    "Audience - performance arts",
    "Audience - motion picture",
    "Classroom/lecture/training",
    "Conf./meet./multi-purpose",
    "Corr. >= 2.4m wide",
    "Corr. < 2.4m wide",
    "Dining - bar lounge/leisure",
    "Dining - family space",
    "Dining - other",
    "Dress./fitt. - performance arts",
    "Electrical/Mechanical",
    "Food preparation",
    "Lab - classrooms",
    "Lab - research",
    "Lobby - elevator",
    "Lobby - performance arts",
    "Lobby - motion picture",
    "Lobby - other",
    "Locker room",
    "Lounge/recreation",
    "Office - enclosed",
    "Office - open plan",
    "Sales area",
    "Stairway",
    "Storage area",
    "Washroom",
    "Workshop space",
    "Automotive - repair",
    "Bank - banking and offices",
    "Convention centre - audience",
    "Convention centre - exhibit",
    "Courthouse - courtroom",
    "Courthouse - cell",
    "Courthouse - chambers",
    "Penitentiary - audience",
    "Penitentiary - classroom",
    "Penitentiary - dining",
    "Dormitory - living quarters",
    "Fire station - engine room",
    "Fire station - quarters",
    "Gym - fitness",
    "Gym - audience",
    "Gym - play",
    "Hospital corr. >= 2.4m",
    "Hospital corr. < 2.4m",
    "Hospital - emergency",
    "Hospital - exam",
    "Hospital - laundry/washing",
    "Hospital - lounge/recreation",
    "Hospital - medical supply",
    "Hospital - nursery",
    "Hospital - nurses' station",
    "Hospital - operating room",
    "Hospital - patient room",
    "Hospital - pharmacy",
    "Hospital - physical therapy",
    "Hospital - radiology/imaging",
    "Hospital - recovery",
    "Hotel/Motel - dining",
    "Hotel/Motel - rooms",
    "Hotel/Motel - lobby",
    "Hway lodging - dining",
    "Hway lodging - rooms",
    "Library - cataloging",
    "Library - reading",
    "Library - stacks",
    "Mfg - corr. >= 2.4m",
    "Mfg - corr. < 2.4m",
    "Mfg - detailed",
    "Mfg - equipment",
    "Mfg - bay H > 15m",
    "Mfg - 7.5 <= bay H <= 15m",
    "Mfg - bay H < 7.5m",
    "Museum - exhibition",
    "Museum - restoration",
    "Parking garage space",
    "Post office sorting",
    "Religious - audience",
    "Religious - fellowship hall",
    "Religious - pulpit/choir",
    "Retail - dressing/fitting",
    "Retail - mall concourse",
    "Retail - sales",
    "Sports arena - audience",
    "Sports arena - court c4",
    "Sports arena - court c3",
    "Sports arena - court c2",
    "Sports arena - court c1",
    "Sports arena - ring",
    "Transp. baggage",
    "Transp. seating",
    "Transp. concourse",
    "Transp. counter",
    "Warehouse - fine",
    "Warehouse - med/blk",
    "Warehouse - med/blk2",
  ]
  def setup()
    #Create new model for testing. 
    @model = OpenStudio::Model::Model.new
    #Create Geometry that will be used for all tests.  
    
    #Below ground story to tests all ground surfaces including roof.
    length = 100.0; width = 100.0 ; num_above_ground_floors = 0; num_under_ground_floors = 1; floor_to_floor_height = 3.8 ; plenum_height = 1; perimeter_zone_depth = 4.57; initial_height = -10.0
    BTAP::Geometry::Wizards::create_shape_rectangle(@model,length, width, num_above_ground_floors,num_under_ground_floors, floor_to_floor_height, plenum_height,perimeter_zone_depth, initial_height )

  end
  
  # Tests to ensure that the NECB default schedules are being defined correctly.
  # This is not for compliance, but for archetype development. 
  # @return [Bool] true if successful. 
  def test_schedule_type_defaults()
    output = ""
    #Iterate through all spacetypes/buildingtypes. 
    Templates.each do |template|
      SpaceTypeNames.each do |name|
        # Create a space type
        stub_space_type = OpenStudio::Model::SpaceType.new(@model)
        stub_space_type.setStandardsBuildingType('Space Function')
        stub_space_type.setStandardsSpaceType(name)
        stub_space_type.setName(name)
        stub_space_type.set_rendering_color(template)
      end
      @model.add_loads(template)
    end
    @model.getSpaceTypes.each do |st|
      

      #Lights
      total_lpd = []
      lpd_sched = []
      st.lights.each {|light| total_lpd << light.powerPerFloorArea.get ; lpd_sched << light.schedule.get.name}
      assert(total_lpd.size <= 1 , "#{total_lpd.size} light definitions given. Expecting <= 1.")
      
      #People / Occupancy
      total_occ_dens = []
      occ_sched = []
      st.people.each {|people_def| total_occ_dens << people_def.peoplePerFloorArea.get ; occ_sched << people_def.numberofPeopleSchedule.get.name}
      assert(total_lpd.size <= 1 , "#{total_occ_dens.size} people definitions given. Expecting <= 1.")   
      
      #Equipment -Gas
      gas_equip_power = []
      gas_equip_sched = []
      st.gasEquipment.each {|gas_equip| gas_equip_power << gas_equip.powerPerFloorArea.get ; gas_equip_sched << gas_equip.schedule.get.name}
      assert( gas_equip_power.size <= 1 , "#{gas_equip_power.size} gas definitions given. Expecting <= 1." ) 
      
      #Equipment -Electric
      elec_equip_power = []
      elec_equip_sched = []
      st.electricEquipment.each {|elec_equip| elec_equip_power << elec_equip.powerPerFloorArea.get ; elec_equip_sched << elec_equip.schedule.get.name}
      assert( elec_equip_power.size <= 1 , "#{elec_equip_power.size} electric definitions given. Expecting <= 1." ) 
      
      #Equipment - Steam
      steam_equip_power = []
      steam_equip_sched = []
      st.steamEquipment.each {|steam_equip| steam_equip_power << steam_equip.powerPerFloorArea.get ; steam_equip_sched << steam_equip.schedule.get.name}
      assert( steam_equip_power.size <= 1 , "#{steam_equip_power.size} steam definitions given. Expecting <= 1." ) 
      
      #Hot Water Equipment
      hw_equip_power = []
      hw_equip_sched = []
      st.hotWaterEquipment.each {|equip| hw_equip_power << equip.powerPerFloorArea.get ; hw_equip_sched << equip.schedule.get.name}
      assert( hw_equip_power.size <= 1 , "#{hw_equip_power.size} hw definitions given. Expecting <= 1." ) 
      
      #Hot Water Equipment
      other_equip_power = []
      other_equip_sched = []
      st.otherEquipment.each {|equip| other_equip_power << equip.powerPerFloorArea.get ; other_equip_sched << equip.schedule.get.name}
      assert( other_equip_power.size <= 1 , "#{other_equip_power.size} other equipment definitions given. Expecting <= 1." ) 
      
      
      output <<  "#{st.name},"
      #lights
      output <<  "#{total_lpd[0]},"
      output << "#{lpd_sched[0]},"
      
      #people
      output <<  "#{total_occ_dens[0]},"
      output << "#{occ_sched[0]},"
      
      #equipment
      output <<  "#{gas_equip_power[0]},"
      output << "#{gas_equip_sched[0]}"

      output << "\n"
      
      
    end
    puts output
  end
  # This test will ensure that the wildcard spacetypes are being assigned the 
  # appropriate schedule.
  # This is not for compliance, but for archetype development. 
  # @return [Bool] true if successful. 
  def wildcard_schedule_defaults_test()
    
  end
  
  # This test will ensure that the loads for each of the 133 spacetypes are 
  # being assigned the appropriate values for SHW, People and Equipment.
  # This is not for compliance, but for archetype development. 
  # @return [Bool] true if successful. 
  def internal_loads_test()
    
  end
  
  # This test will ensure that the loads for each of the 133 spacetypes are 
  # being assigned the appropriate values for LPD.
  # This is not for compliance, but for archetype development. 
  # @return [Bool] true if successful.
  def lighting_power_density_test()
    
  end
  
  
  # This test will ensure that the system selection for each of the 133 spacetypes are 
  # being assigned the appropriate values for LPD.
  # @return [Bool] true if successful.
  def system_selection_test()
    
  end
  
  
end




