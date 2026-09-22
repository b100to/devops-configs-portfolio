saml_provider_name = "authentik"
role_name          = "authentik-admin"

# Downloaded from authentik provider metadata endpoint.
saml_metadata_document = <<-EOT
<md:EntityDescriptor xmlns:samlp="urn:oasis:names:tc:SAML:2.0:protocol" xmlns:saml="urn:oasis:names:tc:SAML:2.0:assertion" xmlns:ds="http://www.w3.org/2000/09/xmldsig#" xmlns:md="urn:oasis:names:tc:SAML:2.0:metadata" xmlns:xenc="http://www.w3.org/2001/04/xmlenc#" ID="_cac10d5ac5bec0b4ffdb8d3e335bbc018f088d14c804b29d735fed3a59d6214f" entityID="urn:amazon:webservices"><ds:Signature>
<ds:SignedInfo>
<ds:CanonicalizationMethod Algorithm="http://www.w3.org/2001/10/xml-exc-c14n#"/>
<ds:SignatureMethod Algorithm="http://www.w3.org/2001/04/xmldsig-more#rsa-sha256"/>
<ds:Reference URI="#_cac10d5ac5bec0b4ffdb8d3e335bbc018f088d14c804b29d735fed3a59d6214f">
<ds:Transforms>
<ds:Transform Algorithm="http://www.w3.org/2000/09/xmldsig#enveloped-signature"/>
<ds:Transform Algorithm="http://www.w3.org/2001/10/xml-exc-c14n#"/>
</ds:Transforms>
<ds:DigestMethod Algorithm="http://www.w3.org/2001/04/xmlenc#sha256"/>
<ds:DigestValue>REPLACE_ME_DIGEST_BASE64</ds:DigestValue>
</ds:Reference>
</ds:SignedInfo>
<ds:SignatureValue>REPLACE_ME_SIGNATURE_BASE64</ds:SignatureValue>
<ds:KeyInfo>
<ds:X509Data>
<ds:X509Certificate>REPLACE_ME_IDP_SIGNING_CERT_BASE64</ds:X509Certificate>
</ds:X509Data>
</ds:KeyInfo>
</ds:Signature><md:IDPSSODescriptor protocolSupportEnumeration="urn:oasis:names:tc:SAML:2.0:protocol"><md:KeyDescriptor use="signing"><ds:KeyInfo><ds:X509Data><ds:X509Certificate>REPLACE_ME_IDP_SIGNING_CERT_BASE64</ds:X509Certificate></ds:X509Data></ds:KeyInfo></md:KeyDescriptor><md:SingleLogoutService Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect" Location="https://sso.acme.example/application/saml/aws-dev/slo/binding/redirect/"/><md:SingleLogoutService Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST" Location="https://sso.acme.example/application/saml/aws-dev/slo/binding/post/"/><md:NameIDFormat>urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress</md:NameIDFormat><md:NameIDFormat>urn:oasis:names:tc:SAML:2.0:nameid-format:persistent</md:NameIDFormat><md:NameIDFormat>urn:oasis:names:tc:SAML:1.1:nameid-format:X509SubjectName</md:NameIDFormat><md:NameIDFormat>urn:oasis:names:tc:SAML:2.0:nameid-format:transient</md:NameIDFormat><md:SingleSignOnService Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect" Location="https://sso.acme.example/application/saml/aws-dev/sso/binding/redirect/"/><md:SingleSignOnService Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST" Location="https://sso.acme.example/application/saml/aws-dev/sso/binding/post/"/></md:IDPSSODescriptor></md:EntityDescriptor>
EOT

policy_arns = [
  "arn:aws:iam::aws:policy/AdministratorAccess",
]

# 1h~12h (3600~43200). 4h default.
max_session_duration = 43200
