class CredentialsPolicy {
  const CredentialsPolicy();

  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static const minPasswordLength = 8;

  CredentialErrors validate({
    required String email,
    required String password,
    String name = '',
    String confirm = '',
    bool registering = false,
  }) {
    final emailText = email.trim();
    return CredentialErrors(
      name: registering && name.trim().isEmpty ? 'Enter your full name.' : null,
      email: emailText.isEmpty
          ? 'Enter your email address.'
          : !_emailRegex.hasMatch(emailText)
              ? 'Enter a valid email address.'
              : null,
      password: password.isEmpty
          ? 'Enter your password.'
          : registering && password.length < minPasswordLength
              ? 'Use at least $minPasswordLength characters.'
              : null,
      confirm:
          registering && confirm != password ? 'Passwords do not match.' : null,
    );
  }
}

class CredentialErrors {
  const CredentialErrors({this.name, this.email, this.password, this.confirm});

  static const none = CredentialErrors();

  final String? name;
  final String? email;
  final String? password;
  final String? confirm;

  bool get isValid =>
      name == null && email == null && password == null && confirm == null;

  @override
  bool operator ==(Object other) =>
      other is CredentialErrors &&
      other.name == name &&
      other.email == email &&
      other.password == password &&
      other.confirm == confirm;

  @override
  int get hashCode => Object.hash(name, email, password, confirm);
}
