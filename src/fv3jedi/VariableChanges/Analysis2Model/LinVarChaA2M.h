/*
 * (C) Copyright 2017-2020  UCAR.
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#pragma once

#include <memory>
#include <ostream>
#include <string>

#include "eckit/config/Configuration.h"
#include "fv3jedi/Geometry/Geometry.h"
#include "LinVarChaA2M.interface.h"
#include "oops/util/Printable.h"

namespace fv3jedi {

// -------------------------------------------------------------------------------------------------

class LinVarChaA2M: public util::Printable {
 public:
  static const std::string classname() {return "fv3jedi::LinVarChaA2M";}
  explicit LinVarChaA2M(const State &, const State &, const Geometry &,
                        const eckit::Configuration &);
  ~LinVarChaA2M();
  void multiply(const Increment &, Increment &) const;
  void multiplyInverse(const Increment &, Increment &) const;
  void multiplyAD(const Increment &, Increment &) const;
  void multiplyInverseAD(const Increment &, Increment &) const;

 private:
  std::shared_ptr<const Geometry> geom_;
  F90lvc_A2M keyFtnConfig_;
  void print(std::ostream &) const override;
};

// -------------------------------------------------------------------------------------------------

}  // namespace fv3jedi
