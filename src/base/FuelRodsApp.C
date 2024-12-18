#include "FuelRodsApp.h"
#include "Moose.h"
#include "AppFactory.h"
#include "ModulesApp.h"
#include "MooseSyntax.h"

InputParameters
FuelRodsApp::validParams()
{
  InputParameters params = MooseApp::validParams();
  params.set<bool>("use_legacy_material_output") = false;
  return params;
}

FuelRodsApp::FuelRodsApp(InputParameters parameters) : MooseApp(parameters)
{
  FuelRodsApp::registerAll(_factory, _action_factory, _syntax);
}

FuelRodsApp::~FuelRodsApp() {}

void 
FuelRodsApp::registerAll(Factory & f, ActionFactory & af, Syntax & s)
{
  ModulesApp::registerAllObjects<FuelRodsApp>(f, af, s);
  Registry::registerObjectsTo(f, {"FuelRodsApp"});
  Registry::registerActionsTo(af, {"FuelRodsApp"});

  /* register custom execute flags, action syntax, etc. here */
}

void
FuelRodsApp::registerApps()
{
  registerApp(FuelRodsApp);
}

/***************************************************************************************************
 *********************** Dynamic Library Entry Points - DO NOT MODIFY ******************************
 **************************************************************************************************/
extern "C" void
FuelRodsApp__registerAll(Factory & f, ActionFactory & af, Syntax & s)
{
  FuelRodsApp::registerAll(f, af, s);
}
extern "C" void
FuelRodsApp__registerApps()
{
  FuelRodsApp::registerApps();
}
