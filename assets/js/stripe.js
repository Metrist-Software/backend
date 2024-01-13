import { loadStripe } from '@stripe/stripe-js';

export const InitSetup = {
  async mounted() {
    const stripe = await loadStripe(this.el.dataset.publicKey)
    let elements
    this.handleEvent("set_payment_client_secret", ({secret}) => {
      const options = {
        clientSecret: secret
      }

      elements = stripe.elements(options);
      const paymentElement = elements.create('payment')

      paymentElement.mount('#payment-element')
      paymentElement.on('ready', () => this.pushEvent('payment_ready', 1))
    })
    this.handleEvent("payment_submit", async () => {
      const {error} = await stripe.confirmSetup({
        elements,
        confirmParams: {
          return_url: this.el.dataset.callbackUrl,
        }
      });

      if (error) {
        this.pushEvent('payment_error', error)
      }
    })
  }
}
