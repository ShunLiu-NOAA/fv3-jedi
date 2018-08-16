/*
 * (C) Copyright 2017 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */


#include <algorithm>
#include <string>

#include "src/IncrementFV3JEDI.h"
#include "eckit/config/LocalConfiguration.h"
#include "oops/base/Variables.h"
#include "oops/generic/UnstructuredGrid.h"
#include "oops/util/Logger.h"
#include "ufo/GeoVaLs.h"
#include "ioda/Locations.h"
#include "ErrorCovarianceFV3JEDI.h"
#include "FieldsFV3JEDI.h"
#include "GeometryFV3JEDI.h"
#include "StateFV3JEDI.h"
#include "oops/util/DateTime.h"
#include "oops/util/Duration.h"
#include "GetValuesTrajFV3JEDI.h"

namespace fv3jedi {

// -----------------------------------------------------------------------------
/// Constructor, destructor
// -----------------------------------------------------------------------------
IncrementFV3JEDI::IncrementFV3JEDI(const GeometryFV3JEDI & resol,
                                    const oops::Variables & vars,
                                    const util::DateTime & vt)
  : fields_(new FieldsFV3JEDI(resol, vars, vt))
{
  fields_->zero();
  oops::Log::trace() << "IncrementFV3JEDI constructed." << std::endl;
}
// -----------------------------------------------------------------------------
IncrementFV3JEDI::IncrementFV3JEDI(const GeometryFV3JEDI & resol,
                                    const IncrementFV3JEDI & other)
  : fields_(new FieldsFV3JEDI(*other.fields_, resol))
{
  oops::Log::trace() << "IncrementFV3JEDI constructed from other." << std::endl;
}
// -----------------------------------------------------------------------------
IncrementFV3JEDI::IncrementFV3JEDI(const IncrementFV3JEDI & other,
                                    const bool copy)
  : fields_(new FieldsFV3JEDI(*other.fields_, copy))
{
  oops::Log::trace() << "IncrementFV3JEDI copy-created." << std::endl;
}
// -----------------------------------------------------------------------------
IncrementFV3JEDI::IncrementFV3JEDI(const IncrementFV3JEDI & other)
  : fields_(new FieldsFV3JEDI(*other.fields_))
{
  oops::Log::trace() << "IncrementFV3JEDI copy-created." << std::endl;
}
// -----------------------------------------------------------------------------
IncrementFV3JEDI::~IncrementFV3JEDI() {
  oops::Log::trace() << "IncrementFV3JEDI destructed" << std::endl;
}
// -----------------------------------------------------------------------------
/// Basic operators
// -----------------------------------------------------------------------------
void IncrementFV3JEDI::diff(const StateFV3JEDI & x1, const StateFV3JEDI & x2) {
  ASSERT(this->validTime() == x1.validTime());
  ASSERT(this->validTime() == x2.validTime());
  oops::Log::debug() << "IncrementFV3JEDI:diff incr " << *fields_ << std::endl;
  oops::Log::debug() << "IncrementFV3JEDI:diff x1 " << x1.fields() << std::endl;
  oops::Log::debug() << "IncrementFV3JEDI:diff x2 " << x2.fields() << std::endl;
  fields_->diff(x1.fields(), x2.fields());
}
// -----------------------------------------------------------------------------
IncrementFV3JEDI & IncrementFV3JEDI::operator=(const IncrementFV3JEDI & rhs) {
  *fields_ = *rhs.fields_;
  return *this;
}
// -----------------------------------------------------------------------------
IncrementFV3JEDI & IncrementFV3JEDI::operator+=(const IncrementFV3JEDI & dx) {
  ASSERT(this->validTime() == dx.validTime());
  *fields_ += *dx.fields_;
  return *this;
}
// -----------------------------------------------------------------------------
IncrementFV3JEDI & IncrementFV3JEDI::operator-=(const IncrementFV3JEDI & dx) {
  ASSERT(this->validTime() == dx.validTime());
  *fields_ -= *dx.fields_;
  return *this;
}
// -----------------------------------------------------------------------------
IncrementFV3JEDI & IncrementFV3JEDI::operator*=(const double & zz) {
  *fields_ *= zz;
  return *this;
}
// -----------------------------------------------------------------------------
void IncrementFV3JEDI::zero() {
  fields_->zero();
}
// -----------------------------------------------------------------------------
void IncrementFV3JEDI::zero(const util::DateTime & vt) {
  fields_->zero(vt);
}
// -----------------------------------------------------------------------------
void IncrementFV3JEDI::axpy(const double & zz, const IncrementFV3JEDI & dx,
                       const bool check) {
  ASSERT(!check || this->validTime() == dx.validTime());
  fields_->axpy(zz, *dx.fields_);
}
// -----------------------------------------------------------------------------
void IncrementFV3JEDI::accumul(const double & zz, const StateFV3JEDI & xx) {
  fields_->axpy(zz, xx.fields());
}
// -----------------------------------------------------------------------------
void IncrementFV3JEDI::schur_product_with(const IncrementFV3JEDI & dx) {
  fields_->schur_product_with(*dx.fields_);
}
// -----------------------------------------------------------------------------
double IncrementFV3JEDI::dot_product_with(const IncrementFV3JEDI & other)
                                           const {
  return dot_product(*fields_, *other.fields_);
}
// -----------------------------------------------------------------------------
void IncrementFV3JEDI::random() {
  fields_->random();
}
// -----------------------------------------------------------------------------
/// Get increment values at observation locations
// -----------------------------------------------------------------------------
void IncrementFV3JEDI::getValuesTL(const ioda::Locations & locs,
                              const oops::Variables & vars,
                              ufo::GeoVaLs & cols,
                              const GetValuesTrajFV3JEDI & traj) const {
  fields_->getValuesTL(locs, vars, cols, traj);
}
// -----------------------------------------------------------------------------
void IncrementFV3JEDI::getValuesAD(const ioda::Locations & locs,
                             const oops::Variables & vars,
                             const ufo::GeoVaLs & cols,
                             const GetValuesTrajFV3JEDI & traj) {
  fields_->getValuesAD(locs, vars, cols, traj);
}
// -----------------------------------------------------------------------------
void IncrementFV3JEDI::ug_coord(oops::UnstructuredGrid & ug,
                                const int & colocated) const {
  fields_->ug_coord(ug, colocated);
}
// -----------------------------------------------------------------------------
void IncrementFV3JEDI::field_to_ug(oops::UnstructuredGrid & ug,
                                   const int & colocated) const {
  fields_->field_to_ug(ug, colocated);
}
// -----------------------------------------------------------------------------
void IncrementFV3JEDI::field_from_ug(const oops::UnstructuredGrid & ug) {
  fields_->field_from_ug(ug);
}
// -----------------------------------------------------------------------------
/// I/O and diagnostics
// -----------------------------------------------------------------------------
void IncrementFV3JEDI::read(const eckit::Configuration & files) {
  fields_->read(files);
}
// -----------------------------------------------------------------------------
void IncrementFV3JEDI::write(const eckit::Configuration & files) const {
  fields_->write(files);
}
// -----------------------------------------------------------------------------
void IncrementFV3JEDI::print(std::ostream & os) const {
  os << std::endl << "  Valid time: " << validTime();
  os << *fields_;
}
// -----------------------------------------------------------------------------
void IncrementFV3JEDI::dirac(const eckit::Configuration & config) {
  fields_->dirac(config);
}
// -----------------------------------------------------------------------------
}  // namespace fv3jedi
