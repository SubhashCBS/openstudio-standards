require_relative 'minitest_helper'
require_relative 'create_doe_prototype_helper'

class TestHospital < CreateDOEPrototypeBuildingTest
  
  building_types = ['Hospital']
  templates = ['DOE Ref Pre-1980','DOE Ref 1980-2004','90.1-2004','90.1-2007','90.1-2010','90.1-2013']
  climate_zones = ['ASHRAE 169-2006-2A','ASHRAE 169-2006-3B','ASHRAE 169-2006-4A','ASHRAE 169-2006-5A']
  
  create_models = true
  run_models = true
  compare_results = true
  
  debug = true
  
  TestHospital.create_run_model_tests(building_types, templates, climate_zones, create_models, run_models, compare_results, debug)
  
end
