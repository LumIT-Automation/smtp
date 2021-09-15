Name:       automation-interface-mta
Version:    RH_VERSION
Release:    RH_RELEASE
Summary:    Automation Interface MTA (commit: GITCOMMIT).

License:    GPLv3+
Source0:    RPM_SOURCE

Requires:   postfix, cyrus-sasl-plain, bc

BuildArch:  noarch

%description
automation-interface-mta

%prep
%setup  -q #unpack tarball

%install
cp -rfa * %{buildroot}

%include %{_topdir}/SPECS/files.spec



