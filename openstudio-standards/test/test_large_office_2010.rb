require_relative 'minitest_helper'
require_relative 'create_doe_prototype_helper'

class TestLargeOffice < CreateDOEPrototypeBuildingTest
  
  building_types = ['LargeOffice']
  templates = ['90.1-2010']
  climate_zones = ['ASHRAE 169-2006-4B']
  
  create_models = true
  run_models = true
  compare_results = true
  
  debug = true
  
  TestLargeOffice.create_run_model_tests(building_types, templates, climate_zones, create_models, run_models, compare_results, debug)
  
end
