%define rel 0.1

Summary: Base condor database for wallaby
Name: condor-wallaby-base-db
Version: 1.0
Release: %{rel}%{?dist}
Group: Applications/System
License: ASL 2.0
URL: http://git.fedorahosted.org/git/grid/wallaby-base-db.git
Source0: %{name}-%{version}-%{rel}.tar.gz
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
Requires: wallaby-utils
BuildArch: noarch

%description
A default database to be loaded into wallaby that provides configuration
options for a condor pool

%prep
%setup -q

%build

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}/%{_var}/lib/wallaby/snapshots
cp condor-base-db.snapshot %{buildroot}/%{_var}/lib/wallaby/snapshots

%clean
rm -rf %{buildroot}

%files
%defattr(-, root, root, -)
%doc LICENSE
%{_var}/lib/wallaby/snapshots/condor-base-db.snapshot

%changelog
* Wed Feb 11 2010 rrati <rrati@redhat> - 1.0-0.1
- Initial package