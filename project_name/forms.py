from django import forms
from django.contrib.auth.forms import UserCreationForm
from geonode.people.models import Profile


class CustomSignupForm(UserCreationForm):
    first_name = forms.CharField(max_length=30, required=True)
    last_name = forms.CharField(max_length=30, required=True)
    organization = forms.CharField(max_length=255, required=True)
    position = forms.CharField(label='Position', max_length=255, required=True)
    email = forms.EmailField(max_length=254)
    field_order = ['first_name', 'last_name', 'email', 'username']

    class Meta:
        model = Profile
        fields = ('username','first_name', 'last_name','email', 'organization', 'city', 'position', 'profile')

    def save(self, commit=True):
        user = super(UserCreationForm, self).save(commit=False)
        user.set_password(self.cleaned_data["password1"])
        user.first_name = self.cleaned_data['first_name']
        user.last_name = self.cleaned_data['last_name']
        user.organization = self.cleaned_data['organization']
        user.city = self.cleaned_data['city']
        user.position = self.cleaned_data['position']
        user.profile = self.cleaned_data['profile']

    def clean_username(self):
        # Since User.username is unique, this check is redundant,
        # but it sets a nicer error message than the ORM. See #13147.
        username = self.cleaned_data["username"]
        try:
            Profile.objects.get(username=username)
        except Profile.DoesNotExist:
            return username
        raise forms.ValidationError(
            self.error_messages['duplicate_username'],
            code='duplicate_username',
        )
        
        if commit:
            user.save()
        return user
