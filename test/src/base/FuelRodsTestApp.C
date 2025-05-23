//* This file is part of the MOOSE framework
//* https://www.mooseframework.org
//*
//* All rights reserved, see COPYRIGHT for full restrictions
//* https://github.com/idaholab/moose/blob/master/COPYRIGHT
//*
//* Licensed under LGPL 2.1, please see LICENSE for details
//* https://www.gnu.org/licenses/lgpl-2.1.html
#include "FuelRodsTestApp.h"
#include "FuelRodsApp.h"
#include "Moose.h"
#include "AppFactory.h"
#include "MooseSyntax.h"

InputParameters
FuelRodsTestApp::validParams()
{
  InputParameters params = FuelRodsApp::validParams();
  params.set<bool>("use_legacy_material_output") = false;
  return params;
}

FuelRodsTestApp::FuelRodsTestApp(InputParameters parameters) : MooseApp(parameters)
{
  FuelRodsTestApp::registerAll(
      _factory, _action_factory, _syntax, getParam<bool>("allow_test_objects"));
}

FuelRodsTestApp::~FuelRodsTestApp() {}

void
FuelRodsTestApp::registerAll(Factory & f, ActionFactory & af, Syntax & s, bool use_test_objs)
{
  FuelRodsApp::registerAll(f, af, s);
  if (use_test_objs)
  {
    Registry::registerObjectsTo(f, {"FuelRodsTestApp"});
    Registry::registerActionsTo(af, {"FuelRodsTestApp"});
  }
}

void
FuelRodsTestApp::registerApps()
{
  registerApp(FuelRodsApp);
  registerApp(FuelRodsTestApp);
}

/***************************************************************************************************
 *********************** Dynamic Library Entry Points - DO NOT MODIFY ******************************
 **************************************************************************************************/
// External entry point for dynamic application loading
extern "C" void
FuelRodsTestApp__registerAll(Factory & f, ActionFactory & af, Syntax & s)
{
  FuelRodsTestApp::registerAll(f, af, s);
}
extern "C" void
FuelRodsTestApp__registerApps()
{
  FuelRodsTestApp::registerApps();
}
