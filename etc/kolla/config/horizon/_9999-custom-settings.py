SITE_BRANDING = "Cirrus"
DEFAULT_THEME = "c3se_theme"
SELECTABLE_THEMES = [("c3se_theme", "C3SETheme", "themes/c3se_theme")]
OPENSTACK_HOST = "{{ kolla_internal_fqdn }}"
# TODO(fprzewozn): URL /v3 suffix is required until Horizon bug #2073639 is resolved
OPENSTACK_KEYSTONE_URL = "{{ horizon_keystone_url }}/v3"
OPENSTACK_KEYSTONE_DEFAULT_ROLE = "{{ keystone_default_user_role }}"

{% if enable_keystone_federation | bool %}
WEBSSO_ENABLED = True
WEBSSO_KEYSTONE_URL = "{{ keystone_public_url }}/v3"
WEBSSO_CHOICES = (
    {% for idp in keystone_identity_providers %}
    ("{{ idp.name }}_{{ idp.protocol }}", "{{ idp.public_name }}"),
    {% endfor %}
    ("credentials", _("Keystone Credentials")),
)
WEBSSO_IDP_MAPPING = {
{% for idp in keystone_identity_providers %}
    "{{ idp.name }}_{{ idp.protocol }}": ("{{ idp.name }}", "{{ idp.protocol }}"),
{% endfor %}
}
WEBSSO_INITIAL_CHOICE=WEBSSO_CHOICES[0][0]
{% endif %}

