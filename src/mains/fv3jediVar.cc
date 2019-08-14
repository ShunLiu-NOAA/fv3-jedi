/*
 * (C) Copyright 2017 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#include "fv3jedi/Localization/instantiateLocalizationFactory.h"
#include "fv3jedi/Run/Run.h"
#include "fv3jedi/Utilities/instantiateObsFilterFactory.h"
#include "fv3jedi/Utilities/instantiateVarChangeFactories.h"
#include "fv3jedi/Utilities/Traits.h"

#include "oops/runs/Variational.h"

int main(int argc,  char ** argv) {
  fv3jedi::Run run(argc, argv);
  fv3jedi::instantiateLocalizationFactory();
  fv3jedi::instantiateVarChangeFactories();
  fv3jedi::instantiateObsFilterFactory();
  oops::Variational<fv3jedi::Traits> var;
  run.execute(var);
  return 0;
}