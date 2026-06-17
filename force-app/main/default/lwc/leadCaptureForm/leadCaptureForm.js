import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import createLead from '@salesforce/apex/LeadCaptureController.createLead';
import getLeadSources from '@salesforce/apex/LeadCaptureController.getLeadSources';

export default class LeadCaptureForm
    extends NavigationMixin(LightningElement) {

    @track firstName       = '';
    @track lastName        = '';
    @track company         = '';
    @track email           = '';
    @track leadSource      = 'Web';
    @track productInterest = '';
    @track isSaving        = false;
    @track sourceOptions   = [];

    // ✅ ADDED: split phone into two tracked properties
    @track countryCode  = '+91';
    @track phoneNumber  = '';

    // ✅ ADDED: country code options list
    countryCodeOptions = [
        { label: '🇮🇳 +91  India',          value: '+91'  },
        { label: '🇺🇸 +1   USA',            value: '+1'   },
        { label: '🇬🇧 +44  UK',             value: '+44'  },
        { label: '🇦🇺 +61  Australia',      value: '+61'  },
        { label: '🇦🇪 +971 UAE',            value: '+971' },
        { label: '🇸🇬 +65  Singapore',      value: '+65'  },
        { label: '🇩🇪 +49  Germany',        value: '+49'  },
        { label: '🇫🇷 +33  France',         value: '+33'  },
        { label: '🇯🇵 +81  Japan',          value: '+81'  },
        { label: '🇨🇳 +86  China',          value: '+86'  },
        { label: '🇧🇷 +55  Brazil',         value: '+55'  },
        { label: '🇿🇦 +27  South Africa',   value: '+27'  },
        { label: '🇸🇦 +966 Saudi Arabia',   value: '+966' },
        { label: '🇨🇦 +1   Canada',         value: '+1'   },
        { label: '🇳🇿 +64  New Zealand',    value: '+64'  },
    ];

    // ✅ ADDED: placeholder hint changes per country
    get phonePlaceholder() {
        const hints = {
            '+91' : '98765 43210',
            '+1'  : '555 123 4567',
            '+44' : '07700 900123',
            '+61' : '0412 345 678',
            '+971': '050 123 4567',
            '+65' : '9123 4567',
            '+49' : '030 12345678',
            '+33' : '06 12 34 56 78',
            '+81' : '090 1234 5678',
            '+86' : '138 0013 8000',
        };
        return hints[this.countryCode] || 'Enter phone number';
    }

    // ✅ ADDED: computed full phone shown in preview and sent to Apex
    get fullPhone() {
        if (!this.phoneNumber) return '';
        return `${this.countryCode} ${this.phoneNumber}`;
    }

    productOptions = [
        { label: 'CRM',         value: 'CRM' },
        { label: 'Analytics',   value: 'Analytics' },
        { label: 'Integration', value: 'Integration' },
        { label: 'Other',       value: 'Other' }
    ];

    // Wire lead sources dynamically from org picklist
    @wire(getLeadSources)
    wiredSources({ data, error }) {
        if (data) {
            this.sourceOptions = data.map(s => ({
                label: s.label, value: s.value
            }));
        }
    }

    // Live score preview — ✅ CHANGED: this.phone → this.phoneNumber
    get liveScore() {
        let s = 0;
        if (this.company)     s += 20;
        if (this.email)       s += 20;
        if (this.phoneNumber) s += 15;   // ← was this.phone
        if (this.leadSource === 'Web')           s += 20;
        if (this.leadSource === 'Word of mouth') s += 30;
        if (this.leadSource === 'Cold Call')      s += 10;
        return s;
    }

    get scoreLabel() {
        const s = this.liveScore;
        return s >= 70 ? `${s} — Hot`
             : s >= 40 ? `${s} — Warm`
             : `${s} — Cold`;
    }

    get scoreBadgeClass() {
        const s = this.liveScore;
        return s >= 70 ? 'badge-hot'
             : s >= 40 ? 'badge-warm'
             : 'badge-cold';
    }

    // Your original handleChange — untouched
    handleChange(e) {
        this[e.target.dataset.field] = e.target.value;
    }

    // ✅ ADDED: two new handlers for the phone field
    handleCountryCodeChange(e) {
        this.countryCode = e.detail.value;
    }

    handlePhoneChange(e) {
        // Strip anything that isn't a digit, space, or dash
        this.phoneNumber = e.target.value.replace(/[^0-9\s\-]/g, '');
    }

    async saveLead() {
        // HTML5 validation — untouched
        const allValid = [...this.template.querySelectorAll(
            'lightning-input, lightning-combobox'
        )].every(el => el.reportValidity());
        if (!allValid) return;

        this.isSaving = true;
        try {
            const leadId = await createLead({
                firstName:       this.firstName,
                lastName:        this.lastName,
                company:         this.company,
                email:           this.email,
                phone:           this.fullPhone,   // ← was this.phone, now sends "+91 98765 43210"
                leadSource:      this.leadSource,
                productInterest: this.productInterest
            });
            this.dispatchEvent(new ShowToastEvent({
                title:   'Lead saved!',
                message: `Score: ${this.liveScore} | Assigned to SDR.`,
                variant: 'success'
            }));
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId:      leadId,
                    objectApiName: 'Lead',
                    actionName:    'view'
                }
            });
            this.resetForm();
        } catch (err) {
            this.dispatchEvent(new ShowToastEvent({
                title:   'Error saving lead',
                message: err.body?.message ?? err.message,
                variant: 'error'
            }));
        } finally {
            this.isSaving = false;
        }
    }

    // ✅ CHANGED: reset countryCode + phoneNumber instead of phone
    resetForm() {
        ['firstName','lastName','company',
         'email','phoneNumber','productInterest']
        .forEach(f => this[f] = '');
        this.leadSource  = 'Web';
        this.countryCode = '+91';        // reset to India
    }
}