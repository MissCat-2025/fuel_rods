#include "WeibullIC.h"

registerMooseObject("raccoonApp", WeibullIC);

InputParameters
WeibullIC::validParams()
{
  InputParameters params = InitialCondition::validParams();
  params.addParam<Real>("scale", 6.2e6, "Scale parameter");
  params.addParam<Real>("shape", 50.0, "Shape parameter");
  params.addParam<Real>("location", 0.0, "Location parameter");
  params.addParam<unsigned int>("seed", 0, "Random number generator seed");
  return params;
}

WeibullIC::WeibullIC(const InputParameters & parameters)
  : InitialCondition(parameters),
    _scale(getParam<Real>("scale")),
    _shape(getParam<Real>("shape")),
    _location(getParam<Real>("location")),
    _seed(getParam<unsigned int>("seed"))
{
  if (_seed > 0)
    MooseRandom::seed(_seed);
}

Real
WeibullIC::value(const Point & /*p*/)
{
  const Real p = MooseRandom::rand();
  return _location + _scale * std::pow(-std::log(1.0 - p), 1.0 / _shape);
}