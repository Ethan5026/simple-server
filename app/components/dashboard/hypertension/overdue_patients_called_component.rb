class Dashboard::Hypertension::OverduePatientsCalledComponent < ApplicationComponent
  attr_reader :data

  def initialize(region:, data:, period:, with_removed_from_overdue_list:)
    @region = region
    @data = data
    @period = period
    @with_removed_from_overdue_list = with_removed_from_overdue_list
    @with_removed_from_overdue_list = with_removed_from_overdue_list
    @rates = gen_rates
  end

  def graph_data
    # TODO: Implement toggle logic. We can reuse the keys in the graph_data but inject the
    # filtered / non filtered data based on the toggle
    {
      overdue: @rates.map { |k, v| { k => v[:overdue] } }.reduce(:merge),
      called: @rates.map { |k, v| { k => v[:called] } }.reduce(:merge),
      percentageCalled: @rates.map do |k, v|
                          { k => v[:percentageCalled] }
                        end.reduce(:merge),
      startDate: @period.advance(months: -17),
      chartProportionalPercentageCalledWithResultAgreedToVisit: @rates.map { |k, v| { k => v[:chartProportionalPercentageCalledWithResultAgreedToVisit] } }.reduce(:merge),
      chartProportionalPercentageCalledWithResultRemindToCallLater: @rates.map { |k, v| { k => v[:chartProportionalPercentageCalledWithResultRemindToCallLater] } }.reduce(:merge),
      chartProportionalPercentageCalledWithResultRemoveFromOverdueList: @rates.map { |k, v| { k => v[:chartProportionalPercentageCalledWithResultRemoveFromOverdueList] } }.reduce(:merge),
      **period_data,
      **graph_external_hover_data
    }
  end

  def graph_external_hover_data
    {
      percentageCalledWithResultAgreedToVisit: @rates.map { |k, v| { k => v[:percentageCalledWithResultAgreedToVisit] } }.reduce(:merge),
      percentageCalledWithResultRemindToCallLater: @rates.map { |k, v| { k => v[:percentageCalledWithResultRemindToCallLater] } }.reduce(:merge),
      percentageCalledWithResultRemoveFromOverdueList: @rates.map { |k, v| { k => v[:percentageCalledWithResultRemoveFromOverdueList] } }.reduce(:merge),
    }
  end

  def gen_rates
    periods
      .reduce({}) { |merged_values, val| merged_values.merge({ val => rand(1..10_000) }) }
      .map do |period, value|
        overdue = value
        overdue_called = rand(0..value + 500)
        percent_called = cap_percentage(overdue_called * 100 / value)
        called_agreed = rand(0..overdue_called)
        called_remind = rand(0..(overdue_called - called_agreed))
        called_remove = overdue_called - called_agreed - called_remind
        called_agreed_percent = called_agreed * 100 / overdue_called
        called_remind_percent = called_remind * 100 / overdue_called
        called_remove_percent = called_remove * 100 / overdue_called
        chart_proportion_called_agreed_percent = percent_called * [called_agreed_percent, 1].max / 100
        chart_proportion_called_remind_percent = percent_called * [called_remind_percent, 1].max / 100
        chart_proportion_called_remove_percent = percent_called * [called_remove_percent, 1].max / 100
        puts overdue_called
        puts called_agreed
        puts called_agreed_percent
      { period => {
        overdue: overdue,
        called: overdue_called,
        percentageCalled: percent_called,
        percentageCalledWithResultAgreedToVisit: called_agreed_percent,
        percentageCalledWithResultRemindToCallLater: called_remind_percent,
        percentageCalledWithResultRemoveFromOverdueList: called_remove_percent,
        
        chartProportionalPercentageCalledWithResultAgreedToVisit: chart_proportion_called_agreed_percent,
        chartProportionalPercentageCalledWithResultRemindToCallLater: chart_proportion_called_remind_percent,
        chartProportionalPercentageCalledWithResultRemoveFromOverdueList: chart_proportion_called_remove_percent,
  
        } }
    end
      .reduce(:merge)
  end

  def periods
    start_period = @period.advance(months: -17)
    Range.new(start_period, @period)
  end

  private

  def cap_percentage(percentage)
    [percentage, 100].min
  end

  def period_data
    {
      startDate: @period.advance(months: -17),
      endDate: period_info(:name),
    }
  end

  def period_info(key)
    data[:period_info].map { |k, v| [k, v[key]] }.to_h
  end
end
