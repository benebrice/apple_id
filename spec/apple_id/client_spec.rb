RSpec.describe AppleID::Client do
  subject { client }
  let(:client) { AppleID::Client.new attributes }
  let(:attributes) { required_attributes }
  let :required_attributes do
    {
      identifier: 'client_id',
      team_id: 'team_id',
      key_id: 'key_id',
      private_key: OpenSSL::PKey::EC.generate('prime256v1')
    }
  end

  describe 'endpoints' do
    its(:authorization_endpoint) { should == 'https://appleid.apple.com/auth/authorize' }
    its(:token_endpoint) { should == 'https://appleid.apple.com/auth/token' }
  end

  describe '#authorization_uri' do
    let(:scope) { nil }
    let(:response_type) { nil }
    let(:query) do
      params = {
        scope: scope,
        response_type: response_type
      }.reject do |k,v|
        v.blank?
      end
      query = URI.parse(client.authorization_uri params).query
      Rack::Utils.parse_query(query).with_indifferent_access
    end

    describe 'scope' do
      subject do
        query[:scope]
      end

      context 'as default' do
        it { should == nil }
      end
    end
  end

  describe '#access_token!' do
    let :access_token do
      client.authorization_code = 'code'
      client.access_token!
    end

    context 'when bearer token is returned' do
      it 'should return AppleID::AccessToken' do
        mock_json :post, client.token_endpoint, 'access_token/bearer' do
          access_token.should be_a AppleID::AccessToken
        end
      end

      context 'when id_token is returned' do
        it 'should include AppleID::IdToken' do
          mock_json :post, client.token_endpoint, 'access_token/bearer_with_id_token' do
            access_token.id_token.should be_a AppleID::IdToken
          end
        end
      end
    end

    context 'when error is returned' do
      it 'should raise AppleID::Client::Error' do
        mock_json :post, client.token_endpoint, 'access_token/invalid_grant', status: 400 do
          expect do
            access_token
          end.to raise_error AppleID::Client::Error, 'invalid_grant'
        end
      end
    end
  end

  describe '#revoke!' do
    context 'when target token givne' do
      it do
        mock_json :post, client.revocation_endpoint, 'revocation/success', status: 200 do
          client.refresh_token = 'refresh_token'
          client.revoke!.should == :success
        end
      end
    end

    context 'otherwise' do
      it do
        expect do
          client.revoke!
        end.to raise_error ArgumentError
      end
    end
  end
end
