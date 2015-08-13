
require "test_plugin_helper"

module ForemanRemoteExecution
  class RunHostsJobTest <  ActiveSupport::TestCase
    include Dynflow::Testing

    let(:proxy) { FactoryGirl.build(:smart_proxy) }
    let(:hostname) { 'myhost.example.com' }
    let(:script) { 'ping -c 5 redhat.com' }
    let(:targeting) { FactoryGirl.create(:targeting, :search_query => "name = #{host.name}", :user => User.current) }
    let(:job_invocation) do
      FactoryGirl.build(:job_invocation).tap do |invocation|
        invocation.targeting = targeting
        invocation.save
      end
    end
    let(:host) { FactoryGirl.create(:host) }
    let(:action) do
      action = create_action(Actions::RemoteExecution::RunHostsJob)
      action.expects(:action_subject).with(job_invocation)
      action.expects(:task).returns(OpenStruct.new(:id => '123'))
      plan_action(action, job_invocation)
    end

    before do
      User.current = users :admin
      action
    end

    it 'resolves the hosts on targeting in plan phase' do
      targeting.hosts.must_include(host)
    end

    it 'triggers the RunHostJob actions on the resolved hosts in run phase' do
      action.expects(:trigger).with(Actions::RemoteExecution::RunHostJob, job_invocation, host)
      action.create_sub_plans
    end
  end
end
