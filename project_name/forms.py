from django import forms
from django.contrib.auth import get_user_model
from django.contrib.auth.forms import UserCreationForm
from geonode.base.enumerations import COUNTRIES

class SignupForm(UserCreationForm):
    first_name = forms.CharField(max_length=30, required=True)
    last_name = forms.CharField(max_length=30, required=True)
    organization = forms.CharField(max_length=255, required=True)
    city = forms.CharField(max_length=255, required=True)
    country = forms.ChoiceField(choices=COUNTRIES, required=True)
    position = forms.CharField(label='Position', max_length=255, required=True)
    field_order = ["username","first_name", "last_name", "email","position","organization","city","country"]

    class Meta:
        model = get_user_model()
        fields = ("username","first_name","last_name","position","organization","city","profile","country")

    def signup(self, request, user):
        user.set_password(self.cleaned_data["password1"])
        user.first_name = self.cleaned_data['first_name']
        user.last_name = self.cleaned_data['last_name']
        user.organization = self.cleaned_data['organization']
        user.city = self.cleaned_data['city']
        user.position = self.cleaned_data['position']
        user.profile = self.cleaned_data['profile']
        user.country = self.cleaned_data['country']
        user.save()

