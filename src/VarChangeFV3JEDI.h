/*
 * (C) Copyright 2017-2018  UCAR.
 * 
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#ifndef SRC_VARCHANGEFV3JEDI_H_
#define SRC_VARCHANGEFV3JEDI_H_

#include <ostream>
#include <string>

#include "Fortran.h"
#include "eckit/config/Configuration.h"
#include "oops/util/Printable.h"

// Forward declarations
namespace eckit {
  class Configuration;
}

namespace fv3jedi {
  class GeometryFV3JEDI;
  class StateFV3JEDI;
  class IncrementFV3JEDI;

// -----------------------------------------------------------------------------
/// FV3JEDI linear change of variable

class VarChangeFV3JEDI: public util::Printable {
 public:
  static const std::string classname() {return "fv3jedi::VarChangeFV3JEDI";}

  explicit VarChangeFV3JEDI(const StateFV3JEDI &, const StateFV3JEDI &,
                            const eckit::Configuration &);
  ~VarChangeFV3JEDI();

/// Perform linear multiplications
  void multiply(const IncrementFV3JEDI &, IncrementFV3JEDI &) const;
  void multiplyInverse(const IncrementFV3JEDI &, IncrementFV3JEDI &) const;
  void multiplyAD(const IncrementFV3JEDI &, IncrementFV3JEDI &) const;
  void multiplyInverseAD(const IncrementFV3JEDI &, IncrementFV3JEDI &) const;

 private:
  F90vcha keyFtnConfig_;
  void print(std::ostream &) const override;
};
// -----------------------------------------------------------------------------

}  // namespace fv3jedi
#endif  // SRC_VARCHANGEFV3JEDI_H_
