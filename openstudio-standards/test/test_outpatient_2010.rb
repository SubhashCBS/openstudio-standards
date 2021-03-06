require_relative 'minitest_helper'
require_relative 'create_doe_prototype_helper'

class TestOutpatient < CreateDOEPrototypeBuildingTest
  
  building_types = ['Outpatient']
  templates = ['90.1-2010']
  climate_zones = ['ASHRAE 169-2006-5A']
  # templates = ['DOE Ref 1980-2004', 'DOE Ref Pre-1980', '90.1-2007', '90.1-2010', '90.1-2013', '90.1-2004'] 
  # climate_zones = ['ASHRAE 169-2006-1A', 'ASHRAE 169-2006-2A','ASHRAE 169-2006-2B',
                   # 'ASHRAE 169-2006-3A', 'ASHRAE 169-2006-3B', 'ASHRAE 169-2006-3C', 'ASHRAE 169-2006-4A',
                   # 'ASHRAE 169-2006-4B', 'ASHRAE 169-2006-4C', 'ASHRAE 169-2006-5A', 'ASHRAE 169-2006-5B',
                   # 'ASHRAE 169-2006-6A', 'ASHRAE 169-2006-6B', 'ASHRAE 169-2006-7A', 'ASHRAE 169-2006-8A'] 
  
  create_models = true
  run_models = true
  compare_results = true
  
  TestOutpatient.create_run_model_tests(building_types, templates, climate_zones, create_models, run_models, compare_results)
  
  # TestOutpatient.compare_test_results(building_types, templates, climate_zones, file_ext="")
     
end
