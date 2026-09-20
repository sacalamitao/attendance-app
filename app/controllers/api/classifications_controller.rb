module Api
  # Lets forms preview the ministry classification without re-implementing
  # the rules in JavaScript. GET /api/classification?birthdate=YYYY-MM-DD&gender=male
  class ClassificationsController < BaseController
    def show
      authorize Attendee, :index?
      birthdate = Date.iso8601(params[:birthdate].to_s) rescue nil
      reference_date = params[:reference_date].present? ? (Date.iso8601(params[:reference_date]) rescue Date.current) : Date.current

      if birthdate.nil?
        return render json: { ministry_classification: nil, ministry_label: nil, age: nil, error: "Enter a valid birthdate." }
      end
      if birthdate > Date.current
        return render json: { ministry_classification: nil, ministry_label: nil, age: nil, error: "Birthdate cannot be in the future." }
      end

      age = MinistryClassifier.age_on(birthdate, reference_date)
      code = MinistryClassifier.call(birthdate: birthdate, gender: params[:gender], reference_date: reference_date)
      error = code ? nil : "Attendees must be at least #{MinistryClassifier::MINIMUM_AGE} years old (currently #{age})."
      render json: { ministry_classification: code, ministry_label: code && Ministry.label(code), age: age, error: error }
    end
  end
end
